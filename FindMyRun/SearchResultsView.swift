//
//  SearchResultsView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct SearchResultsView: View {
    let runService: RunService
    var searchLocation: CLLocationCoordinate2D? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(MyRunsManager.self) private var myRuns
    @Environment(FavoritesManager.self) private var favorites
    @Environment(AppSettings.self) private var appSettings
    @Environment(LocationService.self) private var locationService
    @State private var selectedRun: Run?
    @State private var selectedClubForDetail: Club?
    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false
    @State private var showingMap = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @Namespace private var animation

    private var isDetailShowing: Bool { selectedRun != nil }

    private var sortedRuns: [Run] {
        runService.runs.sortedByDateThenDistance(from: locationService.location)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if showingMap {
                    resultsMapView
                } else {
                    resultsListView
                }
            }
            .background(Color.appBackground)
            .navigationTitle(isDetailShowing || selectedClubForDetail != nil ? "" : "\(sortedRuns.count) Run\(sortedRuns.count == 1 ? "" : "s") Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let club = selectedClubForDetail {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            favorites.toggle(club.id)
                        } label: {
                            Image(systemName: favorites.isFavorite(club.id) ? "star.fill" : "star")
                                .foregroundStyle(favorites.isFavorite(club.id) ? .yellow : Color(.tertiaryLabel))
                                .animation(.spring(duration: 0.2), value: favorites.isFavorite(club.id))
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: URL(string: "https://\(ContentView.shareDomain)/club/\(club.id)")!,
                            subject: Text(club.name),
                            message: Text("Check out \(club.name) on FindMyRun")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Back") {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) { selectedClubForDetail = nil }
                        }
                        .fontWeight(.semibold)
                    }
                } else if isDetailShowing, let run = selectedRun {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            myRuns.toggle(run)
                        } label: {
                            Image(systemName: myRuns.isSaved(run.id) ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(myRuns.isSaved(run.id) ? appSettings.themeColor : .secondary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: URL(string: "https://\(ContentView.shareDomain)/run/\(run.id)")!) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Back") {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                selectedRun = nil
                                forecast = nil
                            }
                        }
                        .fontWeight(.semibold)
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Picker("View", selection: $showingMap) {
                            Image(systemName: "list.bullet").tag(false)
                            Image(systemName: "map").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 80)
                        .disabled(runService.isLoading || runService.runs.isEmpty)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .onChange(of: showingMap) { _, isMap in
                if isMap { fitMapToResults() }
            }
        }
    }

    // MARK: - List View

    private var resultsListView: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if runService.isLoading {
                        ProgressView("Searching…")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = runService.errorMessage {
                        ContentUnavailableView {
                            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        }
                    } else if runService.runs.isEmpty {
                        ContentUnavailableView(
                            "No Runs Found",
                            systemImage: "figure.run.circle",
                            description: Text("Try adjusting your filters.")
                        )
                    } else {
                        ForEach(sortedRuns) { run in
                            if selectedRun?.id != run.id {
                                RunRowView(run: run)
                                    .matchedGeometryEffect(id: run.id, in: animation)
                                    .onTapGesture { selectRun(run) }
                            } else {
                                Color.clear.frame(height: 100)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .opacity(isDetailShowing ? 0.3 : 1)
            .allowsHitTesting(!isDetailShowing)

            if let run = selectedRun {
                detailOverlay(run: run)
                    .transition(.identity)
            }
            if let club = selectedClubForDetail {
                ClubDetailScreen(club: club)
                    .transition(.identity)
            }
        }
    }

    // MARK: - Map View

    private var resultsMapView: some View {
        ZStack(alignment: .top) {
            Map(position: $mapCameraPosition) {
                // User location dot
                if let loc = locationService.location {
                    Annotation("You", coordinate: loc) {
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

                // Search location pin (if different from user location)
                if let loc = searchLocation {
                    Annotation("Search Area", coordinate: loc) {
                        ZStack {
                            Circle()
                                .fill(appSettings.themeColor.opacity(0.2))
                                .frame(width: 28, height: 28)
                            Image(systemName: "mappin.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, appSettings.themeColor)
                        }
                    }
                }

                // Run pins
                ForEach(sortedRuns) { run in
                    if let coord = coordinate(for: run) {
                        let hasRoute = run.routes?.polyline != nil || run.routes?.summaryPolyline != nil
                        Annotation(run.title, coordinate: coord) {
                            Button {
                                selectRun(run)
                            } label: {
                                Image(systemName: "figure.run.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white, hasRoute ? .red : appSettings.themeColor)
                                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControlVisibility(.hidden)
            .ignoresSafeArea(edges: .bottom)

            if let run = selectedRun {
                detailOverlay(run: run)
                    .transition(.identity)
            }
            if let club = selectedClubForDetail {
                ClubDetailScreen(club: club)
                    .transition(.identity)
            }
        }
    }

    // MARK: - Helpers

    private func coordinate(for run: Run) -> CLLocationCoordinate2D? {
        if let lat = run.startLat, let lng = run.startLng {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else if let lat = run.clubs.latitude, let lng = run.clubs.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return nil
    }

    private func fitMapToResults() {
        // Prefer the search location, then fall back to device location
        let anchor = searchLocation ?? locationService.location
        if let loc = anchor {
            // 25 km radius → 50 km diameter; 1° lat ≈ 111 km
            let span = (50.0 / 111.0)
            let region = MKCoordinateRegion(
                center: loc,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
            withAnimation { mapCameraPosition = .region(region) }
            return
        }

        // Fallback: fit all result pins into view
        let coords = runService.runs.compactMap { coordinate(for: $0) }
        guard !coords.isEmpty else { return }

        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLng = coords[0].longitude, maxLng = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
                                   longitudeDelta: max((maxLng - minLng) * 1.5, 0.05))
        )
        withAnimation { mapCameraPosition = .region(region) }
    }

    private func selectRun(_ run: Run) {
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
            selectedRun = run
            forecast = nil
        }
        Task {
            isFetchingForecast = true
            let lat = run.startLat ?? run.clubs.latitude ?? 43.6532
            let lng = run.startLng ?? run.clubs.longitude ?? -79.3832
            forecast = await WeatherService.fetchForecast(for: run.occursAt, latitude: lat, longitude: lng)
            isFetchingForecast = false
        }
    }

    @ViewBuilder
    private func detailOverlay(run: Run) -> some View {
        ZStack(alignment: .top) {
            if let polylineString = run.routes?.polyline ?? run.routes?.summaryPolyline {
                let coordinates = PolylineDecoder.decode(polylineString)
                if !coordinates.isEmpty {
                    RouteMapView(coordinates: coordinates, forecast: forecast)
                        .ignoresSafeArea(edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    mapFallback(for: run)
                }
            } else {
                mapFallback(for: run)
            }

            RunRowView(run: run, forecast: forecast, isFetchingForecast: isFetchingForecast,
                       onClubInfoTapped: { selectedClubForDetail = $0 })
                .matchedGeometryEffect(id: run.id, in: animation)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.horizontal)
                .padding(.top, 8)
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
                Marker(run.address ?? "Start", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
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
                        Text("No route available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
        }
    }

}

// MARK: - Forecast Badge

struct ForecastBadge: View {
    let forecast: DayForecast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: forecast.conditionIcon)
                .font(.body)
                .symbolRenderingMode(.multicolor)

            Text(forecast.conditionName)
                .font(.caption)
                .fontWeight(.semibold)

            Text(forecast.tempRange)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let precip = forecast.precipitationProbability, precip > 0 {
                Label("\(precip)%", systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(routeColor.opacity(0.3), lineWidth: 1))
    }

    private var routeColor: Color {
        forecast.routeColor.swiftUIColor
    }
}

// MARK: - Route Map

struct RouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    var forecast: DayForecast?

    private var polylineColor: Color {
        forecast?.routeColor.swiftUIColor ?? .gray
    }

    var body: some View {
        Map(initialPosition: cameraPosition) {
            MapPolyline(coordinates: coordinates)
                .stroke(polylineColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            if let start = coordinates.first {
                Annotation("Start", coordinate: start) {
                    Circle()
                        .fill(.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }

            if let end = coordinates.last, coordinates.count > 1 {
                Annotation("Finish", coordinate: end) {
                    Circle()
                        .fill(.red)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    private var cameraPosition: MapCameraPosition {
        .region(regionForCoordinates(coordinates))
    }

    private func regionForCoordinates(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLng = coords[0].longitude
        var maxLng = coords[0].longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLng = min(minLng, coord.longitude)
            maxLng = max(maxLng, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4,
            longitudeDelta: (maxLng - minLng) * 1.4
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - RouteWeatherColor → SwiftUI Color

extension RouteWeatherColor {
    var swiftUIColor: Color {
        switch self {
        case .clear:        return Color.gray
        case .cloudy:       return Color.gray
        case .fog:          return Color(red: 0.6, green: 0.6, blue: 0.7)
        case .lightRain:    return Color.cyan
        case .rain:         return Color.gray
        case .freezingRain: return Color(red: 0.4, green: 0.5, blue: 0.8)
        case .snow:         return Color(red: 0.6, green: 0.7, blue: 1.0)
        case .storm:        return Color.purple
        case .hot:          return Color.red
        case .freezing:     return Color(red: 0.3, green: 0.4, blue: 0.9)
        }
    }
}

