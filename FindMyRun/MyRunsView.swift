//
//  MyRunsView.swift
//  FindMyRun
//

import SwiftUI

struct MyRunsView: View {
    let myRuns: MyRunsManager
    @Environment(NotificationManager.self) private var notifications
    @State private var selectedRun: Run?
    @State private var showPermissionAlert = false

    private var sortedRuns: [Run] {
        myRuns.savedRuns.sorted { $0.occursAt < $1.occursAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if myRuns.savedRuns.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(sortedRuns) { run in
                            Button {
                                selectedRun = run
                            } label: {
                                RunRowView(run: run)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .onDelete { offsets in
                            offsets.forEach { myRuns.remove(sortedRuns[$0].id) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Runs")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await toggleNotifications() }
                    } label: {
                        Image(systemName: notifications.notificationsEnabled ? "bell.fill" : "bell.slash")
                            .foregroundStyle(notifications.notificationsEnabled ? .orange : .secondary)
                    }
                }
            }
            .task {
                await notifications.refreshStatus()
            }
            .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings to get 24-hour reminders for your saved runs.")
            }
        }
        .sheet(item: $selectedRun) { run in
            RunDetailSheet(run: run)
        }
    }

    private func toggleNotifications() async {
        if notifications.notificationsEnabled {
            notifications.notificationsEnabled = false
        } else {
            switch notifications.authorizationStatus {
            case .notDetermined:
                let granted = await notifications.requestPermission()
                if granted {
                    notifications.notificationsEnabled = true
                    notifications.scheduleAll(runs: myRuns.savedRuns)
                }
            case .authorized, .provisional, .ephemeral:
                notifications.notificationsEnabled = true
                notifications.scheduleAll(runs: myRuns.savedRuns)
            default:
                showPermissionAlert = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No saved runs yet")
                .font(.title3)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
            Text("Tap the bookmark icon on any run detail to save it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
