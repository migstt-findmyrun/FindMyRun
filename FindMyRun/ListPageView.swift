//
//  ListPageView.swift
//  FindMyRun
//

import SwiftUI
import MapKit

struct ListPageView: View {
    @State private var listService = RunService()
    @State private var selectedRun: Run?
    @Namespace private var animation
    @Environment(MyRunsManager.self) private var myRuns

    private var isDetailShowing: Bool { selectedRun != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if listService.isLoading {
                            ProgressView("Loading runs…")
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let error = listService.errorMessage {
                            ContentUnavailableView {
                                Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
                            } description: {
                                Text(error)
                            }
                        } else if listService.runs.isEmpty {
                            ContentUnavailableView(
                                "No Upcoming Runs",
                                systemImage: "figure.run.circle",
                                description: Text("Check back later for new runs.")
                            )
                        } else {
                            ForEach(listService.runs) { run in
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

                if let run = selectedRun {
                    detailOverlay(run: run)
                        .transition(.identity)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isDetailShowing ? "" : "All Runs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isDetailShowing, let run = selectedRun {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            myRuns.toggle(run)
                        } label: {
                            Image(systemName: myRuns.isSaved(run.id) ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(myRuns.isSaved(run.id) ? .orange : .secondary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Back") {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                selectedRun = nil
                            }
                        }
                        .fontWeight(.semibold)
                        .tint(.orange)
                    }
                }
            }
            .task {
                await listService.fetchAllUpcoming()
            }
        }
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
            let lat = run.startLat ?? 43.6532
            let lng = run.startLng ?? -79.3832
            forecast = await WeatherService.fetchForecast(for: run.occursAt, latitude: lat, longitude: lng)
            isFetchingForecast = false
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
                    .tint(.orange)
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
