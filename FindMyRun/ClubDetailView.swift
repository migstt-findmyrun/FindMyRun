//
//  ClubDetailView.swift
//  FindMyRun
//

import SwiftUI

struct ClubDetailView: View {
    let club: Club
    let favorites: FavoritesManager

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
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                }

                // Links
                linksCard
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
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
                        .foregroundStyle(.orange)
                    Text("\(memberCount) members")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
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
                                .foregroundStyle(.orange)
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
                                .foregroundStyle(.orange)
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
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
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
