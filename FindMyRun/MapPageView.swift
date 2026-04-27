//
//  MapPageView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct MapPageView: View {
    @Binding var selectedTab: AppTab
    let mapService: RunService
    let clubs: [Club]
    @Binding var onlyToday: Bool
    @Binding var onlyTomorrow: Bool
    @Binding var visibleRegion: MKCoordinateRegion?
    let visibleRunCount: Int
    @Binding var searchOverride: [Run]?
    @Binding var searchCenter: CLLocationCoordinate2D?
    @Environment(LocationService.self) private var locationService
    @Environment(AppSettings.self) private var appSettings
    @Environment(FavoritesManager.self) private var favorites
    @Environment(MyRunsManager.self) private var myRuns
    @Environment(NotificationManager.self) private var notifications
    @State private var selectedRun: Run?
    @State private var selectedClubForDetail: Club?
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    ))
    // Derived club locations from runs that have coordinates
    private var clubCoords: [String: CLLocationCoordinate2D] {
        var result: [String: CLLocationCoordinate2D] = [:]
        for run in mapService.runs {
            guard let lat = run.startLat, let lng = run.startLng else { continue }
            if result[run.clubs.id] == nil {
                result[run.clubs.id] = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }
        return result
    }

    // Assign each run a display coordinate, offsetting runs that share the same spot
    private var runPlacements: [(run: Run, coord: CLLocationCoordinate2D, isApproximate: Bool)] {
        // Build raw (run, coord) pairs
        var raw: [(run: Run, coord: CLLocationCoordinate2D, isApproximate: Bool)] = []
        for run in displayedRuns {
            if let lat = run.startLat, let lng = run.startLng {
                raw.append((run, CLLocationCoordinate2D(latitude: lat, longitude: lng), false))
            } else if let fallback = clubCoords[run.clubs.id] {
                raw.append((run, fallback, true))
            } else if let lat = run.clubs.latitude, let lng = run.clubs.longitude {
                raw.append((run, CLLocationCoordinate2D(latitude: lat, longitude: lng), true))
            }
        }

        // Group by rounded coordinate key (≈11m grid)
        let key: (CLLocationCoordinate2D) -> String = {
            String(format: "%.4f,%.4f", $0.latitude, $0.longitude)
        }
        var groups: [String: [(Int, CLLocationCoordinate2D, Bool)]] = [:]
        for (i, item) in raw.enumerated() {
            let k = key(item.coord)
            groups[k, default: []].append((i, item.coord, item.isApproximate))
        }

        // Spread groups with more than one run in a small circle (~40m radius)
        let radius = 0.00035
        var result = raw
        for members in groups.values where members.count > 1 {
            let centre = members[0].1
            for (offset, (idx, _, isApprox)) in members.enumerated() {
                let angle = (2 * Double.pi / Double(members.count)) * Double(offset)
                let newCoord = CLLocationCoordinate2D(
                    latitude: centre.latitude + radius * cos(angle),
                    longitude: centre.longitude + radius * sin(angle)
                )
                result[idx] = (raw[idx].run, newCoord, isApprox)
            }
        }
        return result
    }

    private var displayedRuns: [Run] {
        if let override = searchOverride { return override }
        let cal = Calendar.current
        let nextWeek = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let withinWeek = mapService.runs.filter { $0.occursAt <= nextWeek }
        if onlyToday { return withinWeek.filter { cal.isDateInToday($0.occursAt) } }
        if onlyTomorrow { return withinWeek.filter { cal.isDateInTomorrow($0.occursAt) } }
        return withinWeek
    }

    @State private var userHasPanned = false
    @State private var isProgrammaticMove = false
    @State private var isFilterExpanded = false
    @Namespace private var animation
    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            mapView
                .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 72)

            if let run = selectedRun {
                runDetailCard(run: run)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 72)
                    .transition(.identity)
            }

            if selectedRun == nil {
                VStack {
                    // Search results banner — top left
                    if searchOverride != nil {
                        HStack {
                            Button { searchOverride = nil } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass").font(.caption2)
                                    Text("Search results").font(.caption).fontWeight(.semibold)
                                    Image(systemName: "xmark").font(.caption2)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(.black)
                                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                                )
                                .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    // Filter button — bottom right
                    if searchOverride == nil {
                        HStack {
                            Spacer()
                            quickFilterButton
                        }
                        .padding(.bottom, 88)
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .onAppear {
            locationService.requestPermission()
        }
        .task(id: locationService.location?.latitude) {
            if !userHasPanned { recenter() }
        }
        // Fires on first appear AND whenever searchCenter changes — handles the case
        // where MapPageView is recreated from scratch when switching tabs.
        .task(id: searchCenter?.latitude) {
            guard let coord = searchCenter, searchOverride != nil else { return }
            let span = (10.0 / 111.0) * 2.3
            isProgrammaticMove = true
            userHasPanned = true
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                ))
            }
        }
        .onChange(of: searchOverride?.count) { oldCount, newCount in
            if newCount == nil && oldCount != nil {
                // Results cleared — recenter to user location
                searchCenter = nil
                userHasPanned = false
                recenter()
            }
        }
    }

    // MARK: - Full-screen Map

    private var mapView: some View {
        Map(position: $cameraPosition) {
            if let loc = locationService.location {
                Annotation("Location", coordinate: loc) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }

            ForEach(runPlacements, id: \.run.id) { placement in
                let hasRoute = placement.run.routes?.polyline != nil || placement.run.routes?.summaryPolyline != nil
                Annotation(placement.run.title, coordinate: placement.coord) {
                    Button {
                        selectedRun = placement.run
                    } label: {
                        ZStack {
                            Image(systemName: "figure.run.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white, appSettings.themeColor)
                                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                            if !hasRoute || placement.isApproximate {
                                Circle()
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                    .foregroundStyle(appSettings.themeColor.opacity(0.8))
                                    .frame(width: 34, height: 34)
                            }
                        }
                    }
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            if isProgrammaticMove {
                isProgrammaticMove = false
            } else {
                userHasPanned = true
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControlVisibility(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    @ViewBuilder
    private func runDetailCard(run: Run) -> some View {
        VStack(spacing: 0) {
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
                } else {
                    Button { myRuns.toggle(run) } label: {
                        Image(systemName: myRuns.isSaved(run.id) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(myRuns.isSaved(run.id) ? appSettings.themeColor : .secondary)
                    }
                    Spacer()
                    ShareLink(item: URL(string: "https://\(ContentView.shareDomain)/run/\(run.id)")!) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button("Back") {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            selectedRun = nil
                            selectedClubForDetail = nil
                        }
                    }
                    .fontWeight(.semibold)
                    .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ZStack(alignment: .top) {
                if let polyline = run.routes?.polyline ?? run.routes?.summaryPolyline {
                    let coords = PolylineDecoder.decode(polyline)
                    if !coords.isEmpty {
                        RouteMapView(coordinates: coords, forecast: forecast)
                            .ignoresSafeArea(edges: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else { mapDetailFallback(for: run) }
                } else { mapDetailFallback(for: run) }

                RunRowView(run: run, forecast: forecast, isFetchingForecast: isFetchingForecast,
                           onClubInfoTapped: { selectedClubForDetail = $0 })
                    .opacity(selectedClubForDetail != nil ? 0.3 : 1)
                    .allowsHitTesting(selectedClubForDetail == nil)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if let club = selectedClubForDetail {
                    ClubDetailScreen(club: club).transition(.identity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .background(Color(.systemBackground))
        .task {
            isFetchingForecast = true
            let lat = run.startLat ?? run.clubs.latitude ?? 43.6532
            let lng = run.startLng ?? run.clubs.longitude ?? -79.3832
            forecast = await WeatherService.fetchForecast(for: run.occursAt, latitude: lat, longitude: lng)
            isFetchingForecast = false
        }
    }

    @ViewBuilder
    private func mapDetailFallback(for run: Run) -> some View {
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

    // MARK: - Quick Filter Button

    private var quickFilterButton: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Pills appear ABOVE the button
            if isFilterExpanded {
                VStack(alignment: .trailing, spacing: 8) {
                    filterPill(label: "Today", isActive: onlyToday) {
                        withAnimation(.spring(duration: 0.25)) {
                            onlyToday.toggle()
                            if onlyToday { onlyTomorrow = false }
                        }
                    }
                    filterPill(label: "Tomorrow", isActive: onlyTomorrow) {
                        withAnimation(.spring(duration: 0.25)) {
                            onlyTomorrow.toggle()
                            if onlyTomorrow { onlyToday = false }
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Circle toggle button
            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    isFilterExpanded.toggle()
                    if !isFilterExpanded {
                        onlyToday = false
                        onlyTomorrow = false
                    }
                }
            } label: {
                Image(systemName: (onlyToday || onlyTomorrow) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(.black)
                            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: isFilterExpanded)
    }

    private func filterPill(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? .black : .white)
                .frame(minWidth: 90, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isActive ? Color.white : Color.black)
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                )
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func recenter() {
        guard let loc = locationService.location else { return }
        let span = (10.0 / 111.0) * 2.3
        let offsetCenter = CLLocationCoordinate2D(
            latitude: loc.latitude + span * 0.25,
            longitude: loc.longitude
        )
        isProgrammaticMove = true
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: offsetCenter,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            ))
        }
    }
}

private struct RouteOverlay: Identifiable {
    let id: String
    let coords: [CLLocationCoordinate2D]
}

// MARK: - Run Detail Sheet

struct RunDetailSheet: View {
    let run: Run
    @Environment(\.dismiss) private var dismiss
    @Environment(MyRunsManager.self) private var myRuns
    @Environment(AppSettings.self) private var appSettings
    @Environment(FavoritesManager.self) private var favorites
    @State private var selectedClubForDetail: Club?
    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false

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
                    } else {
                        Button {
                            myRuns.toggle(run)
                        } label: {
                            Image(systemName: myRuns.isSaved(run.id) ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(myRuns.isSaved(run.id) ? appSettings.themeColor : .secondary)
                        }
                        Spacer()
                        ShareLink(item: URL(string: "https://\(ContentView.shareDomain)/run/\(run.id)")!) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                            .padding(.leading, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                ZStack(alignment: .top) {
                    if let polylineString = run.routes?.polyline ?? run.routes?.summaryPolyline {
                        let coordinates = PolylineDecoder.decode(polylineString)
                        if !coordinates.isEmpty {
                            RouteMapView(coordinates: coordinates, forecast: forecast)
                                .ignoresSafeArea(edges: .bottom)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            mapFallback
                        }
                    } else {
                        mapFallback
                    }

                    RunRowView(run: run, forecast: forecast, isFetchingForecast: isFetchingForecast,
                               onClubInfoTapped: { selectedClubForDetail = $0 })
                        .opacity(selectedClubForDetail != nil ? 0.3 : 1)
                        .allowsHitTesting(selectedClubForDetail == nil)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                        .padding(.horizontal)
                        .padding(.top, 8)

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
            .padding(.bottom, 32)
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
    private var mapFallback: some View {
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
            Color.appBackground
                .ignoresSafeArea()
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No route available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }
}

// MARK: - Location Search

struct LocationSearchView: View {
    let onSelect: (CLLocationCoordinate2D, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { item in
                Button {
                    onSelect(item.placemark.coordinate, item.name ?? item.placemark.title ?? "Custom Location")
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if let subtitle = item.placemark.title {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search for a city or address")
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        
                }
            }
            .onChange(of: searchText) { _, query in
                Task {
                    await search(query: query)
                }
            }
        }
    }

    private func search(query: String) async {
        guard query.count >= 2 else {
            results = []
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address

        do {
            let response = try await MKLocalSearch(request: request).start()
            results = response.mapItems
        } catch {
            results = []
        }
    }
}
