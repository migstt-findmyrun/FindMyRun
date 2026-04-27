//
//  SearchPageView.swift
//  FindMyRun
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Search Page

enum SearchMode { case runs, clubs }

struct SearchPageView: View {
    @Binding var selectedTab: AppTab
    @Binding var mapSearchOverride: [Run]?
    @Binding var mapSearchCenter: CLLocationCoordinate2D?
    @Binding var siriRequest: SiriSearchRequest?

    @Environment(AppSettings.self) private var appSettings
    @Environment(LocationService.self) private var locationService
    @Environment(MyRunsManager.self) private var myRuns
    @Environment(FavoritesManager.self) private var favorites

    @State private var searchMode: SearchMode = .runs
    @State private var clubQuery = ""
    @State private var selectedClubForDetail: Club?

    // Location
    @State private var useCurrentLocation = true
    @State private var locationQuery = ""
    @State private var searchCoord: CLLocationCoordinate2D?
    @State private var isResolvingLocation = false

    // Date
    @State private var isRangeMode = false
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil
    @State private var displayMonth: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()

    // Route filter
    enum RouteFilter: String, CaseIterable {
        case any = "Any"
        case withRoute = "With Route"
        case withoutRoute = "No Route"
    }
    @State private var routeFilter: RouteFilter = .any

    // Results
    // Distance filter (route km)
    @State private var minDistanceKm: Double = 0
    @State private var maxDistanceKm: Double = 42

    @State private var runService = RunService()
    @State private var searchResults: [Run] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var scrollToResults = false

    // Detail overlay
    @State private var selectedRun: Run?
    @Namespace private var animation
    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false
    private var isDetailShowing: Bool { selectedRun != nil }

    private var distanceIsFiltered: Bool { minDistanceKm > 0 || maxDistanceKm < 42 }

    private var sundayCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        return cal
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
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
                        Text("Search").font(.headline)
                        Spacer()
                        HStack(spacing: 0) {
                            modePill("Runs", active: searchMode == .runs) {
                                withAnimation(.spring(duration: 0.2)) {
                                    searchMode = .runs
                                    selectedRun = nil
                                }
                            }
                            modePill("Clubs", active: searchMode == .clubs) {
                                withAnimation(.spring(duration: 0.2)) {
                                    searchMode = .clubs
                                    selectedRun = nil
                                }
                            }
                        }
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                ZStack {
                    if searchMode == .clubs {
                        ScrollView { clubsSearchContent }
                            .opacity(selectedClubForDetail != nil ? 0.3 : 1)
                            .allowsHitTesting(selectedClubForDetail == nil)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 12) {
                                    locationSection
                                    dateSection
                                    distanceSection
                                    routeSection
                                    searchButton
                                    if hasSearched {
                                        Color.clear.frame(height: 0).id("results")
                                        Divider().padding(.vertical, 4)
                                        resultsSection
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .padding(.bottom, 20)
                            }
                            .onChange(of: scrollToResults) { _, _ in
                                withAnimation(.spring(duration: 0.5)) {
                                    proxy.scrollTo("results", anchor: .top)
                                }
                            }
                        }
                        .opacity(isDetailShowing || selectedClubForDetail != nil ? 0.3 : 1)
                        .allowsHitTesting(!isDetailShowing && selectedClubForDetail == nil)

                        if let run = selectedRun {
                            detailOverlay(run: run)
                                .opacity(selectedClubForDetail != nil ? 0.3 : 1)
                                .allowsHitTesting(selectedClubForDetail == nil)
                                .transition(.identity)
                        }
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
            async let runs: () = runService.fetchAllUpcoming()
            async let clubs: () = runService.fetchClubs()
            _ = await (runs, clubs)
        }
        .onAppear {
            guard let req = siriRequest else { return }
            siriRequest = nil  // consume it
            applySiriRequest(req)
        }
    }

    private func applySiriRequest(_ req: SiriSearchRequest) {
        // Location
        if let city = req.city, !city.isEmpty {
            useCurrentLocation = false
            locationQuery = city
        }
        // Date range
        isRangeMode = true
        startDate = Calendar.current.startOfDay(for: req.startDate)
        endDate = Calendar.current.startOfDay(for: req.endDate)
        // Distance
        if let min = req.minKm { minDistanceKm = min }
        if let max = req.maxKm { maxDistanceKm = max }
        // Auto-search
        Task { await performSearch() }
    }

    // MARK: - Filter Sections

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Location", icon: "location")

            Toggle(isOn: $useCurrentLocation) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(appSettings.themeColor)
                    Text("Use My Location")
                        .font(.subheadline)
                }
            }
            .tint(appSettings.themeColor)
            .onChange(of: useCurrentLocation) { _, _ in
                searchCoord = nil
                locationQuery = ""
            }

            if !useCurrentLocation {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("City or address", text: $locationQuery)
                        .font(.subheadline)
                        .submitLabel(.search)
                        .onSubmit { Task { await resolveLocation() } }
                    if isResolvingLocation {
                        ProgressView().controlSize(.mini)
                    } else if searchCoord != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.caption)
                    } else if !locationQuery.isEmpty {
                        Button { Task { await resolveLocation() } } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(appSettings.themeColor).font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Date", icon: "calendar")
                Spacer()
                HStack(spacing: 0) {
                    modePill("Day", active: !isRangeMode) {
                        withAnimation(.spring(duration: 0.2)) { isRangeMode = false; endDate = nil }
                    }
                    modePill("Range", active: isRangeMode) {
                        withAnimation(.spring(duration: 0.2)) { isRangeMode = true }
                    }
                }
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            if startDate != nil {
                HStack(spacing: 6) {
                    dateChip(startDate)
                    if isRangeMode {
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                        dateChip(endDate, placeholder: "End date")
                    }
                    Spacer()
                    Button {
                        withAnimation { startDate = nil; endDate = nil }
                    } label: {
                        Text("Clear").font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            MonthCalendarView(
                startDate: $startDate,
                endDate: $endDate,
                isRangeMode: isRangeMode,
                displayMonth: $displayMonth,
                calendar: sundayCalendar,
                themeColor: appSettings.themeColor
            )
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Run Distance", icon: "ruler")
                Spacer()
                if distanceIsFiltered {
                    Button {
                        withAnimation { minDistanceKm = 0; maxDistanceKm = 42 }
                    } label: {
                        Text("Clear").font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(minDistanceKm == 0 ? "Any" : String(format: "%.0f km", minDistanceKm))
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(distanceIsFiltered ? appSettings.themeColor : .secondary)
                Spacer()
                Text(maxDistanceKm >= 42 ? "42+ km" : String(format: "%.0f km", maxDistanceKm))
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(distanceIsFiltered ? appSettings.themeColor : .secondary)
            }
            RangeSlider(
                low: $minDistanceKm,
                high: $maxDistanceKm,
                bounds: 0...42,
                themeColor: appSettings.themeColor
            )
            .padding(.vertical, 4)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Route", icon: "figure.run")
            HStack(spacing: 8) {
                ForEach(RouteFilter.allCases, id: \.self) { filter in
                    routePill(filter)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var searchButton: some View {
        Button { Task { await performSearch() } } label: {
            HStack(spacing: 8) {
                if isSearching {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                }
                Text(isSearching ? "Searching…" : "Search Runs")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(appSettings.themeColor, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isSearching)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(searchResults.isEmpty ? "No Results" : "\(searchResults.count) run\(searchResults.count == 1 ? "" : "s") found")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                if !searchResults.isEmpty {
                    Button {
                        mapSearchCenter = useCurrentLocation ? nil : searchCoord
                        mapSearchOverride = searchResults
                        withAnimation(.spring(duration: 0.3)) { selectedTab = .maps }
                    } label: {
                        Label("Show on Map", systemImage: "map")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(appSettings.themeColor, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if searchResults.isEmpty {
                ContentUnavailableView(
                    "No Runs Found",
                    systemImage: "figure.run.circle",
                    description: Text("Try adjusting your filters.")
                )
                .padding(.top, 12)
            } else {
                ForEach(searchResults) { run in
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

    // MARK: - Clubs Search

    private var filteredClubs: [Club] {
        guard !clubQuery.isEmpty else { return runService.clubs }
        let q = clubQuery.lowercased()
        return runService.clubs.filter {
            $0.name.lowercased().contains(q) ||
            ($0.city?.lowercased().contains(q) ?? false) ||
            ($0.state?.lowercased().contains(q) ?? false) ||
            ($0.country?.lowercased().contains(q) ?? false)
        }
    }

    private var clubsSearchContent: some View {
        VStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search by name or city", text: $clubQuery)
                    .font(.subheadline)
                if !clubQuery.isEmpty {
                    Button { clubQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            if runService.isLoading {
                ProgressView("Loading clubs…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if filteredClubs.isEmpty {
                ContentUnavailableView(
                    clubQuery.isEmpty ? "No Clubs" : "No Clubs Found",
                    systemImage: "magnifyingglass",
                    description: Text(clubQuery.isEmpty ? "Check back soon." : "Try a different name or city.")
                )
                .padding(.top, 12)
            } else {
                ForEach(filteredClubs) { club in
                    clubRow(club)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 20)
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
                    .animation(.spring(duration: 0.2), value: favorites.isFavorite(club.id))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(club.name)
                    .font(.subheadline).fontWeight(.medium)
                if let city = club.city {
                    Text(city)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let count = club.memberCount {
                Text("\(count) members")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Button { selectedClubForDetail = club } label: {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Sub-view helpers

    @ViewBuilder
    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption).fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func dateChip(_ date: Date?, placeholder: String = "Start date") -> some View {
        let hasDate = date != nil
        Text(date.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? placeholder)
            .font(.caption)
            .fontWeight(hasDate ? .semibold : .regular)
            .foregroundStyle(hasDate ? appSettings.themeColor : .secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(hasDate ? appSettings.themeColor.opacity(0.1) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func modePill(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption).fontWeight(active ? .semibold : .regular)
                .foregroundStyle(active ? .white : .secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(active ? appSettings.themeColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: active)
    }

    @ViewBuilder
    private func routePill(_ filter: RouteFilter) -> some View {
        let isActive = routeFilter == filter
        Button { routeFilter = filter } label: {
            Text(filter.rawValue)
                .font(.caption).fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isActive ? appSettings.themeColor : Color(.tertiarySystemBackground),
                            in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isActive)
    }

    // MARK: - Detail overlay

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

    // MARK: - Actions

    private func resolveLocation() async {
        let query = locationQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isResolvingLocation = true
        defer { isResolvingLocation = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        if let item = try? await MKLocalSearch(request: request).start().mapItems.first {
            searchCoord = item.placemark.coordinate
        }
    }

    private func performSearch() async {
        if !useCurrentLocation && searchCoord == nil && !locationQuery.isEmpty {
            await resolveLocation()
        }
        isSearching = true
        defer { isSearching = false }

        if runService.runs.isEmpty {
            await runService.fetchAllUpcoming()
        }

        var results = runService.runs

        // Date filter
        let cal = sundayCalendar
        if let start = startDate {
            if isRangeMode, let end = endDate {
                let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end)!
                results = results.filter { $0.occursAt >= start && $0.occursAt <= endOfDay }
            } else {
                results = results.filter { cal.isDate($0.occursAt, inSameDayAs: start) }
            }
        }

        // Location filter (50 km radius)
        let filterCoord: CLLocationCoordinate2D? = useCurrentLocation ? locationService.location : searchCoord
        if let coord = filterCoord {
            let center = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            results = results.filter { run in
                let lat = run.startLat ?? run.clubs.latitude
                let lng = run.startLng ?? run.clubs.longitude
                guard let lat, let lng else { return true }
                return CLLocation(latitude: lat, longitude: lng).distance(from: center) <= 50_000
            }
        }

        // Route filter
        switch routeFilter {
        case .withRoute:    results = results.filter { $0.routes != nil }
        case .withoutRoute: results = results.filter { $0.routes == nil }
        case .any:          break
        }

        // Distance filter (applies only to runs that have a recorded route distance)
        if distanceIsFiltered {
            results = results.filter { run in
                guard let meters = run.routes?.distanceMeters else { return true }
                let km = meters / 1000
                return km >= minDistanceKm && km <= maxDistanceKm
            }
        }

        searchResults = results.sortedByDateThenDistance(from: locationService.location)
        hasSearched = true
        scrollToResults.toggle()
    }
}

// MARK: - Range Slider

struct RangeSlider: View {
    @Binding var low: Double
    @Binding var high: Double
    let bounds: ClosedRange<Double>
    let themeColor: Color

    @State private var lowAtStart: Double? = nil
    @State private var highAtStart: Double? = nil

    private let handleSize: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let trackWidth = max(1, geo.size.width - handleSize)
            let range = bounds.upperBound - bounds.lowerBound
            let lowX  = CGFloat((low  - bounds.lowerBound) / range) * trackWidth
            let highX = CGFloat((high - bounds.lowerBound) / range) * trackWidth

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 4)
                    .padding(.horizontal, handleSize / 2)

                // Active range fill
                Capsule()
                    .fill(themeColor.opacity(0.7))
                    .frame(width: max(0, highX - lowX), height: 4)
                    .offset(x: lowX + handleSize / 2)

                // Low handle
                Circle()
                    .fill(.white)
                    .frame(width: handleSize, height: handleSize)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    .overlay(Circle().strokeBorder(themeColor, lineWidth: 2))
                    .offset(x: lowX)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            if lowAtStart == nil { lowAtStart = low }
                            let delta = Double(v.translation.width / trackWidth) * range
                            low = max(bounds.lowerBound, min((lowAtStart ?? low) + delta, high - range * 0.02))
                        }
                        .onEnded { _ in lowAtStart = nil }
                    )

                // High handle
                Circle()
                    .fill(.white)
                    .frame(width: handleSize, height: handleSize)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    .overlay(Circle().strokeBorder(themeColor, lineWidth: 2))
                    .offset(x: highX)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            if highAtStart == nil { highAtStart = high }
                            let delta = Double(v.translation.width / trackWidth) * range
                            high = max(low + range * 0.02, min((highAtStart ?? high) + delta, bounds.upperBound))
                        }
                        .onEnded { _ in highAtStart = nil }
                    )
            }
        }
        .frame(height: handleSize)
    }
}

// MARK: - Month Calendar

struct MonthCalendarView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    let isRangeMode: Bool
    @Binding var displayMonth: Date
    let calendar: Calendar
    let themeColor: Color

    private let headers = ["S", "M", "T", "W", "T", "F", "S"]

    private var days: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayMonth)
        let startOfMonth = calendar.date(from: comps)!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        let count = calendar.range(of: .day, in: .month, for: startOfMonth)!.count
        var result: [Date?] = Array(repeating: nil, count: firstWeekday)
        for i in 0..<count {
            result.append(calendar.date(byAdding: .day, value: i, to: startOfMonth))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    var body: some View {
        VStack(spacing: 6) {
            // Month navigation
            HStack {
                Button {
                    displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth)!
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.tertiarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()
                Text(displayMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()

                Button {
                    displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth)!
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.tertiarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
            }

            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                    Text(h)
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        CalendarDayCell(
                            date: date,
                            startDate: startDate,
                            endDate: endDate,
                            isRangeMode: isRangeMode,
                            calendar: calendar,
                            themeColor: themeColor
                        )
                        .onTapGesture { handleTap(date) }
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
    }

    private func handleTap(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        if !isRangeMode {
            if let current = startDate, calendar.isDate(current, inSameDayAs: day) {
                startDate = nil
            } else {
                startDate = day
            }
            return
        }
        // Range mode: first tap = start, second tap after start = end, otherwise reset
        if startDate == nil || (startDate != nil && endDate != nil) {
            startDate = day; endDate = nil
        } else if let start = startDate, day > start {
            endDate = day
        } else {
            startDate = day; endDate = nil
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let startDate: Date?
    let endDate: Date?
    let isRangeMode: Bool
    let calendar: Calendar
    let themeColor: Color

    private var isToday: Bool { calendar.isDateInToday(date) }
    private var isStart: Bool { startDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false }
    private var isEnd: Bool   { endDate.map   { calendar.isDate($0, inSameDayAs: date) } ?? false }
    private var isSelected: Bool { isStart || isEnd }
    private var isInRange: Bool {
        guard isRangeMode, let s = startDate, let e = endDate else { return false }
        return date > s && date < e
    }

    var body: some View {
        Text(date.formatted(.dateTime.day()))
            .font(.caption)
            .fontWeight(isSelected || isToday ? .bold : .regular)
            .foregroundStyle(isSelected ? .white : isToday ? themeColor : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background {
                if isSelected {
                    Circle().fill(themeColor)
                } else if isInRange {
                    RoundedRectangle(cornerRadius: 4).fill(themeColor.opacity(0.12))
                } else if isToday {
                    Circle().stroke(themeColor, lineWidth: 1.5)
                }
            }
    }
}
