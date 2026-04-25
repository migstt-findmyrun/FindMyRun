//
//  MyRunsView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct MyRunsView: View {
    let myRuns: MyRunsManager
    @Environment(NotificationManager.self) private var notifications
    @Environment(AppSettings.self) private var appSettings
    @State private var selectedRun: Run?
    @State private var showPermissionAlert = false
    @Namespace private var animation
    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false

    private var isDetailShowing: Bool { selectedRun != nil }

    private var sortedRuns: [Run] {
        myRuns.savedRuns.sorted { $0.occursAt < $1.occursAt }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header — changes when a run is selected
                HStack {
                    if isDetailShowing, let run = selectedRun {
                        Button { myRuns.toggle(run) } label: {
                            Image(systemName: myRuns.isSaved(run.id) ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(myRuns.isSaved(run.id) ? appSettings.themeColor : .secondary)
                        }
                        Spacer()
                        ShareLink(item: URL(string: "https://\(ContentView.shareDomain)/run/\(run.id)")!) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button("Back") {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) { selectedRun = nil }
                        }
                        .fontWeight(.semibold)
                        .padding(.leading, 8)
                    } else {
                        Text("My Runs").font(.headline)
                        Spacer()
                        if !myRuns.savedRuns.isEmpty {
                            Text("\(myRuns.savedRuns.count) saved")
                                .font(.caption).foregroundStyle(appSettings.themeColor)
                        }
                        Button {
                            Task { await toggleNotifications() }
                        } label: {
                            Image(systemName: notifications.notificationsEnabled ? "bell.fill" : "bell.slash")
                                .foregroundStyle(notifications.notificationsEnabled ? appSettings.themeColor : .secondary)
                        }
                        .padding(.leading, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                ZStack {
                    if myRuns.savedRuns.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(sortedRuns) { run in
                                    if selectedRun?.id != run.id {
                                        SwipeToRemoveRow {
                                            myRuns.remove(run.id)
                                        } content: {
                                            RunRowView(run: run)
                                                .matchedGeometryEffect(id: run.id, in: animation)
                                                .onTapGesture {
                                                    withAnimation(.spring(duration: 0.4, bounce: 0.15)) { selectedRun = run }
                                                }
                                        }
                                    } else {
                                        Color.clear.frame(height: 100)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        .opacity(isDetailShowing ? 0.3 : 1)
                        .allowsHitTesting(!isDetailShowing)
                    }

                    if let run = selectedRun {
                        detailOverlay(run: run).transition(.identity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 72)
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

    @ViewBuilder
    private func detailOverlay(run: Run) -> some View {
        ZStack(alignment: .top) {
            if let polyline = run.routes?.polyline ?? run.routes?.summaryPolyline {
                let coords = PolylineDecoder.decode(polyline)
                if !coords.isEmpty {
                    RouteMapView(coordinates: coords, forecast: forecast)
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else { mapFallback(for: run) }
            } else { mapFallback(for: run) }

            RunRowView(run: run, forecast: forecast, isFetchingForecast: isFetchingForecast)
                .matchedGeometryEffect(id: run.id, in: animation)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.horizontal)
                .padding(.top, 8)
        }
        .task {
            isFetchingForecast = true
            let lat = run.startLat ?? run.clubs.latitude ?? 43.6532
            let lng = run.startLng ?? run.clubs.longitude ?? -79.3832
            forecast = await WeatherService.fetchForecast(for: run.occursAt, latitude: lat, longitude: lng)
            isFetchingForecast = false
        }
    }

    @ViewBuilder
    private func mapFallback(for run: Run) -> some View {
        let lat = run.startLat ?? run.clubs.latitude
        let lng = run.startLng ?? run.clubs.longitude
        if let lat, let lng {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))) {
                Marker(run.address ?? run.clubs.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea(edges: .bottom)
        } else {
            Color(.systemGroupedBackground).ignoresSafeArea()
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "map").font(.system(size: 48)).foregroundStyle(.tertiary)
                        Text("No route available").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
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
        ContentUnavailableView(
            "No Saved Runs",
            systemImage: "bookmark",
            description: Text("Tap the bookmark icon on any run to save it here.")
        )
    }
}

// MARK: - Swipe to Remove

private struct SwipeToRemoveRow<Content: View>: View {
    let onRemove: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    private let revealWidth: CGFloat = 72
    private let threshold: CGFloat = -60

    var body: some View {
        ZStack(alignment: .trailing) {
            // Red button revealed on swipe
            Button(action: triggerRemove) {
                VStack(spacing: 4) {
                    Image(systemName: "bookmark.slash.fill")
                        .font(.title3)
                    Text("Remove")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(width: revealWidth)
                .frame(maxHeight: .infinity)
                .background(.red, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .opacity(offset < 0 ? Double(min(-offset / 20, 1)) : 0)

            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard value.translation.width < 0 else {
                                if offset < 0 { offset = 0 }
                                return
                            }
                            withAnimation(.interactiveSpring()) {
                                offset = max(value.translation.width, -(revealWidth + 12))
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < threshold {
                                triggerRemove()
                            } else {
                                withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }

    private func triggerRemove() {
        withAnimation(.spring(duration: 0.3)) {
            offset = -500
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onRemove()
        }
    }
}
