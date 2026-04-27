//
//  club_detail.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct ClubDetailScreen: View {
    let club: Club
    @Environment(AppSettings.self) private var appSettings
    @Environment(FavoritesManager.self) private var favorites

    var body: some View {
        ZStack(alignment: .top) {
            // Map background centred on club location
            if let lat = club.latitude, let lng = club.longitude {
                // Centre shifted north so the pin appears below the info card
                let span = 0.03
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat + span * 0.3, longitude: lng),
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                ))) {
                    Marker(club.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Color.appBackground
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "map")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("No location available")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
            }

            // Club info card floating on top
            clubCard
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }

    private var clubCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name + member count pill
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(club.name)
                        .font(.headline)
                        .fontDesign(.rounded)

                    if let location = locationString {
                        Label(location, systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let count = club.memberCount {
                    Text("\(count) members")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(appSettings.themeColor.gradient, in: Capsule())
                }
            }

            // Description snippet
            if let description = club.description, !description.isEmpty {
                Divider()
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Links
            let hasWebsite = club.website != nil
            let hasStrava = club.stravaURL != nil
            if hasWebsite || hasStrava {
                Divider()
                HStack(spacing: 16) {
                    if let website = club.website, let url = URL(string: website) {
                        Link(destination: url) {
                            Label("Website", systemImage: "globe")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(appSettings.themeColor)
                        }
                    }
                    if let stravaURL = club.stravaURL {
                        Link(destination: stravaURL) {
                            Label("Strava", systemImage: "figure.run.circle.fill")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(appSettings.themeColor)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var locationString: String? {
        let parts = [club.city, club.state, club.country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
