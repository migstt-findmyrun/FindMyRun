//
//  ContentView.swift
//  FindMyRun
//

import SwiftUI

struct ContentView: View {
    @State private var runService = RunService()
    @State private var stravaService = StravaAuthService()
    @State private var locationService = LocationService()
    @State private var favorites = FavoritesManager()
    @State private var notifications = NotificationManager()
    @State private var myRuns = MyRunsManager()
    @State private var appSettings = AppSettings()
    @State private var selectedTab: AppTab = .maps

    // Search filters
    @State private var selectedDate: Date?
    @State private var selectedEndDate: Date?
    @State private var selectedFlexibility: DateFlexibility = .exact
    @State private var selectedClubIds: Set<String> = []
    @State private var minDistanceKm: Double = 0
    @State private var maxDistanceKm: Double = 50
    @State private var requiresRoute = false
    @State private var showResults = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map List", systemImage: "map.fill", value: .maps) {
                mapsPage
            }

            Tab("List", systemImage: "list.bullet", value: .list) {
                listPage
            }

            Tab("Fav Clubs", systemImage: "star.fill", value: .favorites) {
                favoritesPage
            }

            Tab("My Runs", systemImage: "figure.run", value: .myRuns) {
                myRunsPage
            }

            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                searchPage
            }

        }
        .tint(appSettings.themeColor)
        .toolbarBackground(Color.white, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(locationService)
        .environment(favorites)
        .environment(myRuns)
        .environment(notifications)
        .environment(appSettings)
        .onAppear {
            locationService.requestPermission()
        }
        .task {
            await runService.fetchClubs()
            myRuns.notifications = notifications
            await notifications.refreshStatus()
        }
    }

    // MARK: - Search Page

    private var searchPage: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Search card — always visible
                        SearchCardView(
                            selectedDate: $selectedDate,
                            selectedClubIds: $selectedClubIds,
                            minDistanceKm: $minDistanceKm,
                            maxDistanceKm: $maxDistanceKm,
                            requiresRoute: $requiresRoute,
                            endDate: $selectedEndDate,
                            flexibility: $selectedFlexibility,
                            clubs: runService.clubs,
                            favorites: favorites,
                            onSearch: {
                                showResults = true
                                Task {
                                    // Compute effective date range from flexibility
                                    let effectiveEnd: Date?
                                    if let start = selectedDate, selectedFlexibility != .exact {
                                        let days = selectedFlexibility.days
                                        effectiveEnd = Calendar.current.date(byAdding: .day, value: days, to: start)
                                    } else {
                                        effectiveEnd = selectedEndDate
                                    }

                                    let effectiveStart: Date?
                                    if let start = selectedDate, selectedFlexibility != .exact {
                                        let days = selectedFlexibility.days
                                        effectiveStart = Calendar.current.date(byAdding: .day, value: -days, to: start)
                                    } else {
                                        effectiveStart = selectedDate
                                    }

                                    await runService.searchRuns(
                                        date: effectiveStart,
                                        endDate: effectiveEnd,
                                        clubIds: selectedClubIds,
                                        minKm: minDistanceKm,
                                        maxKm: maxDistanceKm,
                                        requiresRoute: requiresRoute
                                    )
                                }
                            }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showResults) {
                SearchResultsView(runService: runService)
            }
        }
    }

    // MARK: - Favorites Page

    private var favoritesPage: some View {
        FavoritesPageView(allClubs: runService.clubs, favorites: favorites)
    }

    // MARK: - Maps Page

    private var mapsPage: some View {
        MapPageView()
    }

    // MARK: - List Page

    private var listPage: some View {
        ListPageView()
    }

    // MARK: - My Runs Page

    private var myRunsPage: some View {
        MyRunsView(myRuns: myRuns)
    }
}

enum AppTab {
    case search, favorites, maps, list, strava, myRuns
}

#Preview {
    ContentView()
}
