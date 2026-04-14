//
//  FavoritesPageView.swift
//  FindMyRun
//

import SwiftUI

struct FavoritesPageView: View {
    let allClubs: [Club]
    let favorites: FavoritesManager
    @State private var favService = RunService()
    @State private var localClubs: [Club] = []
    @State private var clubsExpanded = false
    @State private var selectedRun: Run?
    @State private var showRunDetail = false
    @State private var selectedClubForDetail: Club?

    private var displayClubs: [Club] {
        localClubs.isEmpty ? allClubs : localClubs
    }

    // Group runs from embedded club data — no dependency on clubs loading separately
    private var groupedRuns: [(club: Club, runs: [Run])] {
        let favoriteIds = favorites.favoriteClubIds
        guard !favoriteIds.isEmpty else { return [] }
        let filtered = favService.runs.filter { favoriteIds.contains($0.clubs.id) }
        let dict = Dictionary(grouping: filtered) { $0.clubs.id }
        return dict.compactMap { _, runs -> (club: Club, runs: [Run])? in
            guard let first = runs.first else { return nil }
            return (club: first.clubs, runs: runs.sorted { $0.occursAt < $1.occursAt })
        }
        .sorted { $0.club.name < $1.club.name }
    }

    var body: some View {
        NavigationStack {
            List {
                // Club selector — expandable
                Section {
                    if clubsExpanded {
                        ForEach(displayClubs) { club in
                            HStack(spacing: 12) {
                                Button {
                                    favorites.toggle(club.id)
                                } label: {
                                    Image(systemName: favorites.isFavorite(club.id) ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundStyle(favorites.isFavorite(club.id) ? .yellow : Color(.tertiaryLabel))
                                        .frame(width: 28)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(club.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if let city = club.city {
                                        Text(city)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if let count = club.memberCount {
                                    Text("\(count) members")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                Button {
                                    selectedClubForDetail = club
                                } label: {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            clubsExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Label("Favourite Clubs", systemImage: "star.circle.fill")
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                            Spacer()
                            if !favorites.favoriteClubIds.isEmpty {
                                Text("\(favorites.favoriteClubIds.count) selected")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Image(systemName: clubsExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Upcoming runs grouped by club
                if favService.isLoading {
                    Section {
                        ProgressView("Loading runs…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                } else if favorites.favoriteClubIds.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Favourite Clubs",
                            systemImage: "star",
                            description: Text("Star a club above to see its upcoming runs.")
                        )
                    }
                } else if groupedRuns.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Upcoming Runs",
                            systemImage: "figure.run.circle",
                            description: Text("Your favourite clubs don't have any runs scheduled right now.")
                        )
                    }
                } else {
                    ForEach(groupedRuns, id: \.club.id) { group in
                        Section {
                            ForEach(group.runs) { run in
                                RunRowView(run: run)
                                    .onTapGesture {
                                        selectedRun = run
                                        showRunDetail = true
                                    }
                            }
                        } header: {
                            HStack {
                                Text(group.club.name)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(group.runs.count) run\(group.runs.count == 1 ? "" : "s")")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fav Clubs")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await favService.fetchClubs()
                localClubs = favService.clubs
            }
            .task(id: favorites.favoriteClubIds) {
                guard !favorites.favoriteClubIds.isEmpty else {
                    favService.runs = []
                    return
                }
                await favService.fetchAllUpcoming()
            }
            .refreshable {
                guard !favorites.favoriteClubIds.isEmpty else { return }
                await favService.fetchAllUpcoming()
            }
            .sheet(isPresented: $showRunDetail) {
                if let run = selectedRun {
                    RunDetailSheet(run: run)
                }
            }
            .sheet(item: $selectedClubForDetail) { club in
                NavigationStack {
                    ClubDetailView(club: club, favorites: favorites)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { selectedClubForDetail = nil }
                            }
                        }
                }
            }
        }
    }
}
