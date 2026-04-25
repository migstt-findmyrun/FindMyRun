//
//  ListPageView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct ListPageView: View {
    let runs: [Run]
    var isLoading: Bool = false
    @Environment(AppSettings.self) private var appSettings
    @Environment(LocationService.self) private var locationService
    @State private var selectedRun: Run?
    @Namespace private var animation
    @Environment(MyRunsManager.self) private var myRuns
    @State private var showAll = false
    @State private var allRunsService = RunService()
    private var isDetailShowing: Bool { selectedRun != nil }

    private var activeRuns: [Run] {
        showAll ? allRunsService.runs : runs
    }

    private var sortedRuns: [Run] {
        activeRuns.sortedByDateThenDistance(from: locationService.location)
    }

    private var isActivelyLoading: Bool {
        showAll ? allRunsService.isLoading : isLoading
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Main list card
            VStack(spacing: 0) {
                // Custom header — always above the detail overlay
                HStack {
                    if isDetailShowing, let run = selectedRun {
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
                        Button("Back") {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) { selectedRun = nil }
                        }
                        .fontWeight(.semibold)
                        .padding(.leading, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Runs").font(.headline)
                            HStack(spacing: 4) {
                                Image(systemName: showAll ? "globe" : "map").font(.caption2)
                                Text(showAll ? "All upcoming runs" : "Runs from map view").font(.caption2)
                            }.foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(duration: 0.3)) { showAll.toggle() }
                        } label: {
                            Text(showAll ? "Map View" : "Show All")
                                .font(.subheadline).fontWeight(.medium)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                // Content area — detail overlay only covers this zone
                ZStack {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if isActivelyLoading {
                                ProgressView("Loading runs…")
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            } else if sortedRuns.isEmpty {
                                ContentUnavailableView(
                                    "No Upcoming Runs",
                                    systemImage: "figure.run.circle",
                                    description: Text(showAll ? "Check back later for new runs." : "Try adjusting the map view or tap \"Show All\".")
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
                        detailOverlay(run: run).transition(.identity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 72)

        }
        .task(id: showAll) {
            if showAll && allRunsService.runs.isEmpty {
                await allRunsService.fetchAllUpcoming()
            }
        }
        .onDisappear { showAll = false }
    }

    private func selectRun(_ run: Run) {
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
            selectedRun = run
        }
    }

    @State private var forecast: DayForecast?
    @State private var isFetchingForecast = false

    @ViewBuilder
    private func detailOverlay(run: Run) -> some View {
        ZStack(alignment: .top) {
            // Map fills background
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

            // Card floating on top
            RunRowView(run: run, forecast: forecast, isFetchingForecast: isFetchingForecast)
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
