//
//  SettingsView.swift
//  FindMyRun
//

import SwiftUI

struct SettingsView: View {
    var onDismiss: () -> Void = {}
    @Environment(AppSettings.self) private var appSettings
    @Environment(NotificationManager.self) private var notifications

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings").font(.headline)
                    Spacer()
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(appSettings.themeColor)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // MARK: Appearance
                        sectionHeader("Appearance", icon: "paintpalette.fill")

                        VStack(spacing: 0) {
                            HStack {
                                Text("Theme Colour")
                                    .font(.subheadline)
                                Spacer()
                                ColorPicker("", selection: Bindable(appSettings).themeColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 32, height: 32)
                            }
                            .padding(16)

                            Divider().padding(.leading, 16)

                            VStack(alignment: .leading, spacing: 10) {
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
                                                    Circle().stroke(Color.primary.opacity(0.35), lineWidth: 3)
                                                        .opacity(isSelected(preset.color) ? 1 : 0)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                        // MARK: Run Reminders
                        sectionHeader("Run Reminders", icon: "bell.fill")

                        VStack(spacing: 0) {
                            Picker(selection: Bindable(notifications).advanceHours) {
                                ForEach(NotificationManager.advanceOptions, id: \.self) { hours in
                                    Text(hours == 1 ? "1 hour" : hours < 24 ? "\(hours) hours" : hours == 24 ? "24 hours (day before)" : "48 hours (2 days before)")
                                        .tag(hours)
                                }
                            } label: {
                                Text("Notify me")
                                    .font(.subheadline)
                            }
                            .pickerStyle(.navigationLink)
                            .padding(16)

                            Divider().padding(.leading, 16)

                            Text("How far in advance to send a notification for saved runs.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(16)
                        }
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                        // MARK: Widget
                        sectionHeader("Widget", icon: "rectangle.on.rectangle")

                        VStack(spacing: 0) {
                            HStack {
                                Text("Enable Widget Data")
                                    .font(.subheadline)
                                Spacer()
                                Toggle("", isOn: Bindable(appSettings).widgetEnabled)
                                    .labelsHidden()
                            }
                            .padding(16)

                            Divider().padding(.leading, 16)

                            Text("Controls what the widget displays. To add the widget to your home screen, long-press the home screen and tap +.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(16)
                        }
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                        // MARK: About
                        sectionHeader("About", icon: "info.circle.fill")

                        HStack {
                            Text("App Version")
                                .font(.subheadline)
                            Spacer()
                            Text("1.6")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 72)
        }
        .tint(appSettings.themeColor)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func isSelected(_ color: Color) -> Bool {
        UIColor(appSettings.themeColor).isApproximatelyEqual(to: UIColor(color))
    }

    private var presetColors: [(label: String, color: Color)] {[
        ("Charcoal",  Color(white: 0.33)),
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
