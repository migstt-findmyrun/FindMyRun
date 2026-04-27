//
//  ClubDetailView.swift
//  FindMyRun
//

import SwiftUI

// MARK: - Card-style Club Detail (matches run detail card aesthetic)

struct ClubDetailCard: View {
    let club: Club
    let favorites: FavoritesManager
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header — star (left) + share + Done (right)
                HStack {
                    Button {
                        favorites.toggle(club.id)
                    } label: {
                        Image(systemName: favorites.isFavorite(club.id) ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(favorites.isFavorite(club.id) ? .yellow : Color(.tertiaryLabel))
                            .animation(.spring(duration: 0.2), value: favorites.isFavorite(club.id))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    ShareLink(
                        item: URL(string: "https://\(ContentView.shareDomain)/club/\(club.id)")!,
                        subject: Text(club.name),
                        message: Text("Check out \(club.name) on FindMyRun")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .padding(.trailing, 8)

                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Club name + location
                        VStack(alignment: .leading, spacing: 6) {
                            Text(club.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)

                            if let location = locationString {
                                Label(location, systemImage: "mappin.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let memberCount = club.memberCount {
                                Label("\(memberCount) members", systemImage: "person.3.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(appSettings.themeColor)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                        // Description
                        if let description = club.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("About", systemImage: "info.circle.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        }

                        // Links
                        let hasWebsite = club.website != nil
                        let hasStrava = club.stravaURL != nil
                        if hasWebsite || hasStrava {
                            VStack(spacing: 0) {
                                Label("Links", systemImage: "link")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 14)
                                    .padding(.bottom, 8)

                                Divider().padding(.horizontal, 16)

                                if let website = club.website, let url = URL(string: website) {
                                    Link(destination: url) {
                                        HStack {
                                            Image(systemName: "globe")
                                                .foregroundStyle(appSettings.themeColor)
                                                .frame(width: 28)
                                            Text("Club Website")
                                                .font(.subheadline).fontWeight(.medium)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    if hasStrava { Divider().padding(.leading, 44) }
                                }

                                if let stravaURL = club.stravaURL {
                                    Link(destination: stravaURL) {
                                        HStack {
                                            Image(systemName: "figure.run.circle.fill")
                                                .foregroundStyle(appSettings.themeColor)
                                                .frame(width: 28)
                                            Text("View on Strava")
                                                .font(.subheadline).fontWeight(.medium)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .presentationBackground(Color.appBackground)
    }

    private var locationString: String? {
        [club.city, club.state, club.country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .nilIfEmpty
    }
}

// MARK: - Navigation-embedded Club Detail (used in Favorites + RunRowView)

struct ClubDetailView: View {
    let club: Club
    let favorites: FavoritesManager
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header card
                headerCard

                // Description
                if let description = club.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About", systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Text(description)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                }

                // Links
                linksCard
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 49) }
        .background(Color.appBackground)
        .navigationTitle(club.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(club.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)

                    if let location = locationString {
                        Label(location, systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Favorite toggle
                Button {
                    favorites.toggle(club.id)
                } label: {
                    Image(systemName: favorites.isFavorite(club.id) ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(favorites.isFavorite(club.id) ? .yellow : Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }

            if let memberCount = club.memberCount {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.caption)
                        .foregroundStyle(appSettings.themeColor)
                    Text("\(memberCount) members")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Links Card

    @ViewBuilder
    private var linksCard: some View {
        let hasWebsite = club.website != nil
        let hasStrava = club.stravaURL != nil

        if hasWebsite || hasStrava {
            VStack(spacing: 0) {
                Label("Links", systemImage: "link")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                Divider().padding(.horizontal, 16)

                if let website = club.website, let url = URL(string: website) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.body)
                                .foregroundStyle(appSettings.themeColor)
                                .frame(width: 28)
                            Text("Club Website")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if hasStrava { Divider().padding(.leading, 44) }
                }

                if let stravaURL = club.stravaURL {
                    Link(destination: stravaURL) {
                        HStack {
                            Image(systemName: "figure.run.circle.fill")
                                .font(.body)
                                .foregroundStyle(appSettings.themeColor)
                                .frame(width: 28)
                            Text("View on Strava")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                Spacer(minLength: 0)
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

    private var locationString: String? {
        [club.city, club.state, club.country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
