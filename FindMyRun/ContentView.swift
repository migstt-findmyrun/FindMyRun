//
//  ContentView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var runService = RunService()
    @State private var stravaService = StravaAuthService()
    @State private var locationService = LocationService()
    @State private var favorites = FavoritesManager()
    @State private var notifications = NotificationManager()
    @State private var myRuns = MyRunsManager()
    @State private var appSettings = AppSettings()
    @State private var selectedTab: AppTab = .maps
    @State private var mapService = RunService()
    @State private var mapOnlyToday = false
    @State private var mapOnlyTomorrow = false
    @State private var mapVisibleRegion: MKCoordinateRegion?
    @State private var deepLinkedRun: Run?
    @State private var deepLinkedClub: Club?
    @State private var deepLinkService = RunService()
    @State private var showSettings = false
    @State private var mapSearchOverride: [Run]? = nil
    @State private var mapSearchCenter: CLLocationCoordinate2D? = nil
    @State private var siriSearchRequest: SiriSearchRequest? = nil

    private var mapDisplayedRuns: [Run] {
        let cal = Calendar.current
        let nextWeek = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let withinWeek = mapService.runs.filter { $0.occursAt <= nextWeek }
        if mapOnlyToday { return withinWeek.filter { cal.isDateInToday($0.occursAt) } }
        if mapOnlyTomorrow { return withinWeek.filter { cal.isDateInTomorrow($0.occursAt) } }
        return withinWeek
    }

    /// Runs whose coordinates fall within the map's current visible region.
    private var visibleRuns: [Run] {
        guard let region = mapVisibleRegion else { return mapDisplayedRuns }
        return mapDisplayedRuns.filter { run in
            let lat = run.startLat ?? run.clubs.latitude
            let lng = run.startLng ?? run.clubs.longitude
            guard let lat, let lng else { return false }
            let latOK = abs(lat - region.center.latitude) <= region.span.latitudeDelta / 2
            let lngOK = abs(lng - region.center.longitude) <= region.span.longitudeDelta / 2
            return latOK && lngOK
        }
    }

    static let shareDomain = "findmyrun.app"

    var body: some View {
        ZStack(alignment: .bottom) {
            // Active page
            Group {
                switch selectedTab {
                case .maps:      mapsPage
                case .list:      listPage
                case .search:    searchPage
                case .favorites: favoritesPage
                case .myRuns:    myRunsPage
                }
            }
            .tint(appSettings.themeColor)
            .environment(locationService)
            .environment(favorites)
            .environment(myRuns)
            .environment(notifications)
            .environment(appSettings)

            // Floating tab bar — card width, slightly into safe area
            floatingTabBar
                .padding(.horizontal, 12)
                .padding(.bottom, -10)
                .frame(maxWidth: .infinity)
        }
        .task {
            await runService.fetchClubs()
            await mapService.fetchAllUpcoming()
            myRuns.notifications = notifications
            await notifications.refreshStatus()
        }
        .onOpenURL { url in
            guard url.host == Self.shareDomain,
                  url.pathComponents.count == 3 else { return }
            let type = url.pathComponents[1]
            let id   = url.pathComponents[2]
            Task { @MainActor in
                switch type {
                case "run":
                    if let run = await deepLinkService.fetchRun(id: id) {
                        deepLinkedRun = run
                    }
                case "club":
                    if let club = await deepLinkService.fetchClub(id: id) {
                        deepLinkedClub = club
                    }
                default:
                    break
                }
            }
        }
        .sheet(item: $deepLinkedRun) { run in
            RunDetailSheet(run: run)
                .environment(locationService)
                .environment(favorites)
                .environment(myRuns)
                .environment(appSettings)
        }
        .sheet(item: $deepLinkedClub) { club in
            ClubDetailCard(club: club, favorites: favorites)
                .environment(appSettings)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(appSettings)
                .environment(notifications)
        }
        .onAppear {
            guard let tab = UserDefaults(suiteName: SharedRunStore.appGroupID)?.string(forKey: "siriRequestedTab") else { return }
            UserDefaults(suiteName: SharedRunStore.appGroupID)?.removeObject(forKey: "siriRequestedTab")
            switch tab {
            case "myRuns":
                selectedTab = .myRuns
            case "search":
                siriSearchRequest = SharedRunStore.loadSiriRequest()
                selectedTab = .search
            default:
                break
            }
        }
    }

    // MARK: - Floating Pill Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabBarButton(tab: .maps,      icon: "house",            activeIcon: "house.fill")
            tabBarButton(tab: .list,      icon: "square.grid.2x2",  activeIcon: "square.grid.2x2.fill")

            tabBarButton(tab: .search, icon: "magnifyingglass", activeIcon: "magnifyingglass")

            tabBarButton(tab: .favorites, icon: "star",              activeIcon: "star.fill")
            tabBarButton(tab: .myRuns,    icon: "figure.run",        activeIcon: "figure.run")

            // Separator + Settings
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1, height: 28)
                .padding(.horizontal, 4)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: -6)
    }

    @ViewBuilder
    private func tabBarButton(tab: AppTab, icon: String, activeIcon: String) -> some View {
        let isActive = selectedTab == tab
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                if isActive {
                    Circle()
                        .fill(.white)
                        .frame(width: 50, height: 50)
                }
                Image(systemName: isActive ? activeIcon : icon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(isActive ? .black : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isActive)
    }

    // MARK: - Favorites Page

    private var favoritesPage: some View {
        FavoritesPageView(allClubs: runService.clubs, favorites: favorites)
    }

    // MARK: - Maps Page

    private var mapsPage: some View {
        MapPageView(selectedTab: $selectedTab, mapService: mapService, clubs: runService.clubs, onlyToday: $mapOnlyToday, onlyTomorrow: $mapOnlyTomorrow, visibleRegion: $mapVisibleRegion, visibleRunCount: visibleRuns.count, searchOverride: $mapSearchOverride, searchCenter: $mapSearchCenter)
    }

    // MARK: - List Page

    private var listPage: some View {
        ListPageView(runs: visibleRuns, isLoading: mapService.isLoading)
    }

    // MARK: - Search Page

    private var searchPage: some View {
        SearchPageView(selectedTab: $selectedTab, mapSearchOverride: $mapSearchOverride, mapSearchCenter: $mapSearchCenter, siriRequest: $siriSearchRequest)
    }

    // MARK: - My Runs Page

    private var myRunsPage: some View {
        MyRunsView(myRuns: myRuns)
    }
}

enum AppTab {
    case maps, list, search, favorites, myRuns
}

#Preview {
    ContentView()
}
