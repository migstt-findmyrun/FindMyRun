//
//  MapPageView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct MapPageView: View {
    @Environment(LocationService.self) private var locationService
    @State private var mapService = RunService()
    @State private var radiusKm: Double = 10
    @State private var showLocationSearch = false
    @State private var customLocation: CLLocationCoordinate2D?
    @State private var selectedRun: Run?
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    ))
    @State private var onlyToday = false
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

    private var activeLocation: CLLocationCoordinate2D? {
        customLocation ?? locationService.location
    }

    private var displayedRuns: [Run] {
        let cal = Calendar.current
        let nextWeek = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let withinWeek = mapService.runs.filter { $0.occursAt <= nextWeek }
        guard onlyToday else { return withinWeek }
        return withinWeek.filter { cal.isDateInToday($0.occursAt) }
    }

    private var runsWithRoutes: [RouteOverlay] {
        displayedRuns.compactMap { run in
            guard let polyline = run.routes?.polyline ?? run.routes?.summaryPolyline else { return nil }
            let coords = PolylineDecoder.decode(polyline)
            guard !coords.isEmpty else { return nil }
            return RouteOverlay(id: run.id, coords: coords)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                // Location dot — blue regardless of GPS or custom
                if let loc = activeLocation {
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

                // Radius circle around active search centre
                if let center = activeLocation {
                    MapCircle(center: center, radius: radiusKm * 1000)
                        .foregroundStyle(.orange.opacity(0.07))
                        .stroke(.orange.opacity(0.25), lineWidth: 1)
                }

                // Run markers — with per-cluster offset to separate overlapping pins
                ForEach(runPlacements, id: \.run.id) { placement in
                    let hasRoute = placement.run.routes?.polyline != nil || placement.run.routes?.summaryPolyline != nil
                    Annotation(placement.run.title, coordinate: placement.coord) {
                        Button {
                            selectedRun = placement.run
                        } label: {
                            ZStack {
                                Image(systemName: "figure.run.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white, hasRoute ? .red : .orange)
                                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                                if placement.isApproximate {
                                    Circle()
                                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .frame(width: 34, height: 34)
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControlVisibility(.hidden)
            .ignoresSafeArea(edges: .bottom)

            // Controls overlay
            VStack(alignment: .leading, spacing: 8) {
                // Title card
                VStack(spacing: 4) {
                    Text("Find My Run")
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.red)
                    Text("Discover group runs near you — find your crew, pick a route, and go.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color(.darkGray).opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                // Location button
                HStack(spacing: 8) {
                    Button {
                        showLocationSearch = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.viewfinder")
                                .font(.caption)
                            Text("Set Different Location")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThickMaterial, in: Capsule())
                    }

                    if customLocation != nil {
                        Button {
                            customLocation = nil
                            fetchAndRecenter()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                Text("Use My Location")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThickMaterial, in: Capsule())
                        }
                    }
                }

                // Search radius
                HStack(spacing: 6) {
                    Text("Search Radius:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach([5.0, 10.0, 20.0, 50.0], id: \.self) { r in
                        Button {
                            radiusKm = r
                            fetchAndRecenter()
                        } label: {
                            Text("\(Int(r)) km")
                                .font(.caption)
                                .fontWeight(radiusKm == r ? .bold : .regular)
                                .foregroundStyle(radiusKm == r ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(radiusKm == r ? Color.orange : Color.clear, in: Capsule())
                                .overlay(Capsule().stroke(radiusKm == r ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Legend + today filter
                HStack(spacing: 8) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.run.circle.fill")
                                .foregroundStyle(.white, .red)
                                .font(.callout)
                            Text("Has route")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "figure.run.circle.fill")
                                .foregroundStyle(.white, .orange)
                                .font(.callout)
                            Text("No route")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThickMaterial, in: Capsule())

                    Button {
                        onlyToday.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: onlyToday ? "calendar.circle.fill" : "calendar.circle")
                                .font(.caption)
                            Text("Only Today's Runs")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(onlyToday ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(onlyToday ? Color.orange : Color.clear, in: Capsule())
                        .background(.ultraThickMaterial, in: Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: activeLocation?.latitude) {
            guard activeLocation != nil else { return }
            fetchAndRecenter()
        }
        .onChange(of: radiusKm) { _, _ in fetchAndRecenter() }
        .sheet(isPresented: $showLocationSearch) {
            LocationSearchView(onSelect: { coordinate in
                customLocation = coordinate
                showLocationSearch = false
            })
        }
        .sheet(item: $selectedRun) { run in
            RunDetailSheet(run: run)
        }
    }

    private func fetchAndRecenter() {
        guard let loc = activeLocation else { return }
        Task {
            await mapService.fetchNearbyRuns(latitude: loc.latitude, longitude: loc.longitude, radiusKm: radiusKm)
            recenter()
        }
    }

    private func recenter() {
        guard let loc = activeLocation else { return }
        // 1 degree ≈ 111 km; add 30% padding around the search radius
        let span = (radiusKm / 111.0) * 2.3
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: loc,
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
    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Map background
                if let polylineString = run.routes?.polyline ?? run.routes?.summaryPolyline {
                    let coordinates = PolylineDecoder.decode(polylineString)
                    if !coordinates.isEmpty {
                        RouteMapView(coordinates: coordinates, forecast: forecast)
                            .ignoresSafeArea(edges: .bottom)
                    } else {
                        mapFallback
                    }
                } else {
                    mapFallback
                }

                // Card on top
                RunRowView(run: run, forecast: forecast, isFetchingForecast: isFetchingForecast)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        myRuns.toggle(run)
                    } label: {
                        Image(systemName: myRuns.isSaved(run.id) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(myRuns.isSaved(run.id) ? .orange : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(.orange)
                }
            }
            .task {
                isFetchingForecast = true
                let lat = run.startLat ?? 43.6532
                let lng = run.startLng ?? -79.3832
                forecast = await WeatherService.fetchForecast(for: run.occursAt, latitude: lat, longitude: lng)
                isFetchingForecast = false
            }
        }
    }

    @ViewBuilder
    private var mapFallback: some View {
        if let lat = run.startLat, let lng = run.startLng {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))) {
                Marker(run.address ?? "Start", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                    .tint(.orange)
            }
            .mapStyle(.standard(elevation: .flat))
            .ignoresSafeArea(edges: .bottom)
        } else {
            Color(.systemGroupedBackground)
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
    let onSelect: (CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { item in
                Button {
                    onSelect(item.placemark.coordinate)
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
                        .tint(.orange)
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
