//
//  SettingsView.swift
//  FindMyRun
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings
    @Environment(NotificationManager.self) private var notifications

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Theme Colour", systemImage: "paintpalette.fill")
                        Spacer()
                        ColorPicker("", selection: Bindable(appSettings).themeColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 32, height: 32)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Presets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(presetColors, id: \.label) { preset in
                                Button {
                                    appSettings.themeColor = preset.color
                                } label: {
                                    Circle()
                                        .fill(preset.color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle().stroke(Color.primary.opacity(0.3), lineWidth: 3)
                                                .opacity(isSelected(preset.color) ? 1 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Appearance")
                }

                Section {
                    Picker(selection: Bindable(notifications).advanceHours) {
                        ForEach(NotificationManager.advanceOptions, id: \.self) { hours in
                            Text(hours == 1 ? "1 hour" : hours < 24 ? "\(hours) hours" : hours == 24 ? "24 hours (day before)" : "48 hours (2 days before)")
                                .tag(hours)
                        }
                    } label: {
                        Label("Notify me", systemImage: "bell.fill")
                    }
                } header: {
                    Text("Run Reminders")
                } footer: {
                    Text("How far in advance to send a notification for saved runs.")
                }

                Section("About") {
                    Label("App Version 1.0", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(appSettings.themeColor)
    }

    private func isSelected(_ color: Color) -> Bool {
        UIColor(appSettings.themeColor).isApproximatelyEqual(to: UIColor(color))
    }

    private var presetColors: [(label: String, color: Color)] {[
        ("Blue",      .blue),
        ("Red",       .red),
        ("Green",     Color(red: 0.2, green: 0.6, blue: 0.3)),
        ("Purple",    .purple),
        ("Orange",    .orange),
    ]}
}

private extension UIColor {
    func isApproximatelyEqual(to other: UIColor, tolerance: CGFloat = 0.05) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1-r2) < tolerance && abs(g1-g2) < tolerance && abs(b1-b2) < tolerance
    }
}
