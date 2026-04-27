//
//  ProfileView.swift
//  FindMyRun
//

import SwiftUI

struct ProfileView: View {
    @Bindable var stravaService: StravaAuthService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if stravaService.isAuthenticated {
                        authenticatedView
                    } else {
                        connectView
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        
                }
            }
        }
    }

    // MARK: - Connect with Strava

    private var connectView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.gray)

            Text("Connect with Strava")
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)

            Text("Link your Strava account to see your running stats and get personalized pace estimates.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task { await stravaService.authorize() }
            } label: {
                HStack {
                    Image(systemName: "link")
                    Text("Connect with Strava")
                }
                .font(.headline)
                .fontDesign(.rounded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            
            .padding(.horizontal)

            if stravaService.isLoading {
                ProgressView("Connecting…")
            }

            if let error = stravaService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Authenticated Profile

    private var authenticatedView: some View {
        VStack(spacing: 20) {
            // Athlete header
            if let athlete = stravaService.athlete {
                VStack(spacing: 8) {
                    // Avatar
                    if let urlString = athlete.profile, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.gray)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    }

                    Text(athlete.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)

                    if let city = athlete.city, let state = athlete.state {
                        Text("\(city), \(state)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Running stats
            if let stats = stravaService.stats {
                // Recent runs
                if let recent = stats.recentRunTotals {
                    StatsCard(title: "Recent Runs (4 weeks)", stats: recent)
                }

                // Year to date
                if let ytd = stats.ytdRunTotals {
                    StatsCard(title: "Year to Date", stats: ytd)
                }

                // All time
                if let allTime = stats.allRunTotals {
                    StatsCard(title: "All Time", stats: allTime)
                }
            }

            // Logout
            Button(role: .destructive) {
                stravaService.logout()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Disconnect Strava")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

// MARK: - Stats Card

private struct StatsCard: View {
    let title: String
    let stats: ActivityTotal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                if let count = stats.count {
                    StatItem(icon: "number", label: "Runs", value: "\(count)")
                    Spacer()
                }
                if let distance = stats.distanceKm {
                    StatItem(icon: "figure.run", label: "Distance", value: distance)
                    Spacer()
                }
                if let pace = stats.averagePace {
                    StatItem(icon: "speedometer", label: "Avg Pace", value: pace)
                    Spacer()
                }
                if let elevation = stats.elevationGain {
                    StatItem(icon: "mountain.2.fill", label: "Elevation", value: String(format: "%.0f m", elevation))
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

private struct StatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.gray)
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
