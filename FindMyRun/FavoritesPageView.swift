//
//  FavoritesPageView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct FavoritesPageView: View {
    let allClubs: [Club]
    let favorites: FavoritesManager
    @Environment(AppSettings.self) private var appSettings
    @Environment(MyRunsManager.self) private var myRuns
    @State private var favService = RunService()
    @State private var localClubs: [Club] = []
    @State private var selectedRun: Run?
    @State private var selectedClubForDetail: Club?
    @State private var clubSearchQuery = ""
    @State private var collapsedClubs: Set<String> = []
    @Namespace private var animation
    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false

    private var isDetailShowing: Bool { selectedRun != nil }

    private var displayClubs: [Club] {
        let base = localClubs.isEmpty ? allClubs : localClubs
        guard !clubSearchQuery.isEmpty else { return base }
        let q = clubSearchQuery.lowercased()
        return base.filter {
            $0.name.lowercased().contains(q) ||
            ($0.city?.lowercased().contains(q) ?? false) ||
            ($0.state?.lowercased().contains(q) ?? false) ||
            ($0.country?.lowercased().contains(q) ?? false) ||
            ($0.description?.lowercased().contains(q) ?? false)
        }
    }

    // Favorited clubs that have no upcoming runs
    private var clubsWithNoRuns: [Club] {
        let clubsWithRunIds = Set(groupedRuns.map { $0.club.id })
        let base = localClubs.isEmpty ? allClubs : localClubs
        return base
            .filter { favorites.isFavorite($0.id) && !clubsWithRunIds.contains($0.id) }
            .sorted { $0.name < $1.name }
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
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            // Main card
            VStack(spacing: 0) {
                // Custom header — changes when a run is selected
                HStack {
                    if let club = selectedClubForDetail {
                        Button { favorites.toggle(club.id) } label: {
                            Image(systemName: favorites.isFavorite(club.id) ? "star.fill" : "star")
                                .foregroundStyle(favorites.isFavorite(club.id) ? .yellow : Color(.tertiaryLabel))
                                .animation(.spring(duration: 0.2), value: favorites.isFavorite(club.id))
                        }
                        Spacer()
                        ShareLink(
                            item: URL(string: "https://\(ContentView.shareDomain)/club/\(club.id)")!,
                            subject: Text(club.name),
                            message: Text("Check out \(club.name) on FindMyRun")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button("Back") {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) { selectedClubForDetail = nil }
                        }
                        .fontWeight(.semibold)
                        .padding(.leading, 8)
                    } else if isDetailShowing, let run = selectedRun {
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
                        Text(clubSearchQuery.isEmpty ? "Clubs" : "Search Results").font(.headline)
                        Spacer()
                        if !clubSearchQuery.isEmpty {
                            Text("\(displayClubs.count) club\(displayClubs.count == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(appSettings.themeColor)
                        } else if !favorites.favoriteClubIds.isEmpty {
                            Text("\(favorites.favoriteClubIds.count) favourited")
                                .font(.caption).foregroundStyle(appSettings.themeColor)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                ZStack {
                    if !clubSearchQuery.isEmpty {
                        // Search results
                        if displayClubs.isEmpty {
                            ContentUnavailableView("No Clubs Found", systemImage: "magnifyingglass",
                                description: Text("Try a different name or city."))
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(displayClubs) { club in
                                        clubRow(club)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                        }
                    } else {
                        // Normal favorites view
                        if favService.isLoading {
                            ProgressView("Loading runs…").frame(maxWidth: .infinity).padding(.top, 40)
                        } else if favorites.favoriteClubIds.isEmpty {
                            ContentUnavailableView("No Favourite Clubs", systemImage: "star",
                                description: Text("Use the search tab to find and star clubs."))
                        } else if groupedRuns.isEmpty && clubsWithNoRuns.isEmpty {
                            ContentUnavailableView("No Upcoming Runs", systemImage: "figure.run.circle",
                                description: Text("Your favourite clubs don't have any runs scheduled right now."))
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    // Clubs with no upcoming runs
                                    ForEach(clubsWithNoRuns) { club in
                                        HStack(spacing: 10) {
                                            Button {
                                                withAnimation(.spring(duration: 0.3)) {
                                                    favorites.toggle(club.id)
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(club.name)
                                                    .font(.subheadline).fontWeight(.semibold)
                                                    .foregroundStyle(.primary)
                                                Text("No upcoming runs")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Button { selectedClubForDetail = club } label: {
                                                Image(systemName: "info.circle")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                                    }

                                    ForEach(groupedRuns, id: \.club.id) { group in
                                        let isCollapsed = collapsedClubs.contains(group.club.id)
                                        VStack(spacing: 10) {
                                            // Club header with collapse toggle + remove button
                                            HStack(spacing: 10) {
                                                // Remove from favourites
                                                Button {
                                                    withAnimation(.spring(duration: 0.3)) {
                                                        favorites.toggle(group.club.id)
                                                    }
                                                } label: {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.title3)
                                                        .foregroundStyle(.red)
                                                }
                                                .buttonStyle(.plain)

                                                // Club name + run count — tap to collapse/expand
                                                Button {
                                                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                                                        if isCollapsed {
                                                            collapsedClubs.remove(group.club.id)
                                                        } else {
                                                            collapsedClubs.insert(group.club.id)
                                                        }
                                                    }
                                                } label: {
                                                    HStack(spacing: 6) {
                                                        Text(group.club.name)
                                                            .font(.subheadline).fontWeight(.semibold)
                                                            .foregroundStyle(appSettings.themeColor)
                                                        Spacer()
                                                        Text("\(group.runs.count) run\(group.runs.count == 1 ? "" : "s")")
                                                            .font(.caption).foregroundStyle(.secondary)
                                                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(appSettings.themeColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                                            if !isCollapsed {
                                                ForEach(group.runs) { run in
                                                    if selectedRun?.id != run.id {
                                                        RunRowView(run: run, onClubInfoTapped: { selectedClubForDetail = $0 })
                                                            .matchedGeometryEffect(id: run.id, in: animation)
                                                            .onTapGesture {
                                                                withAnimation(.spring(duration: 0.4, bounce: 0.15)) { selectedRun = run }
                                                            }
                                                    } else {
                                                        Color.clear.frame(height: 100)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            .opacity(isDetailShowing ? 0.3 : 1)
                            .allowsHitTesting(!isDetailShowing)
                        }
                    }

                    if let run = selectedRun {
                        detailOverlay(run: run).transition(.identity)
                    }
                    if let club = selectedClubForDetail {
                        ClubDetailScreen(club: club).transition(.identity)
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
            await favService.fetchClubs()
            localClubs = favService.clubs
        }
        .task(id: favorites.favoriteClubIds) {
            guard !favorites.favoriteClubIds.isEmpty else { favService.runs = []; return }
            await favService.fetchAllUpcoming()
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

            RunRowView(run: run, forecast: forecast, isFetchingForecast: isFetchingForecast,
                       onClubInfoTapped: { selectedClubForDetail = $0 })
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
            Color.appBackground.ignoresSafeArea()
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "map").font(.system(size: 48)).foregroundStyle(.tertiary)
                        Text("No route available").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
        }
    }

    @ViewBuilder
    private func clubRow(_ club: Club) -> some View {
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
                    .font(.subheadline).fontWeight(.medium)
                if let city = club.city {
                    Text(city).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let count = club.memberCount {
                Text("\(count) members").font(.caption2).foregroundStyle(.tertiary)
            }
            Button { selectedClubForDetail = club } label: {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

}
