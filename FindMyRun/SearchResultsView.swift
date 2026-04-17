//
//  SearchResultsView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct SearchResultsView: View {
    let runService: RunService
    @Environment(\.dismiss) private var dismiss
    @Environment(MyRunsManager.self) private var myRuns
    @Environment(AppSettings.self) private var appSettings
    @State private var selectedRun: Run?
    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false
    @Namespace private var animation

    private var isDetailShowing: Bool { selectedRun != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                // Results list
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
                            ForEach(runService.runs) { run in
                                if selectedRun?.id != run.id {
                                    RunRowView(run: run)
                                        .matchedGeometryEffect(id: run.id, in: animation)
                                        .onTapGesture {
                                            selectRun(run)
                                        }
                                } else {
                                    Color.clear
                                        .frame(height: 100)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .opacity(isDetailShowing ? 0.3 : 1)
                .allowsHitTesting(!isDetailShowing)

                // Detail overlay
                if let run = selectedRun {
                    detailOverlay(run: run)
                        .transition(.identity)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isDetailShowing ? "" : "\(runService.runs.count) Run\(runService.runs.count == 1 ? "" : "s") Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isDetailShowing, let run = selectedRun {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            myRuns.toggle(run)
                        } label: {
                            Image(systemName: myRuns.isSaved(run.id) ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(myRuns.isSaved(run.id) ? appSettings.themeColor : .secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isDetailShowing ? "Back" : "Done") {
                        if isDetailShowing {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                selectedRun = nil
                                forecast = nil
                            }
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    
                }
            }
        }
    }

    private func selectRun(_ run: Run) {
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
            selectedRun = run
            forecast = nil
        }

        // Fetch weather forecast for this run's date and location
        Task {
            isFetchingForecast = true
            let lat = run.startLat ?? 43.6532
            let lng = run.startLng ?? -79.3832
            forecast = await WeatherService.fetchForecast(for: run.occursAt, latitude: lat, longitude: lng)
            isFetchingForecast = false
        }
    }

    @ViewBuilder
    private func detailOverlay(run: Run) -> some View {
        ZStack(alignment: .top) {
            // Map fills the entire background
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

            // Card floating on top of map
            RunRowView(run: run, forecast: forecast, isFetchingForecast: isFetchingForecast)
                .matchedGeometryEffect(id: run.id, in: animation)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func mapFallback(for run: Run) -> some View {
        if let lat = run.startLat, let lng = run.startLng {
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

