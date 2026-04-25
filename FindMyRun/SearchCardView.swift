//
//  SearchCardView.swift
//  FindMyRun
//

import SwiftUI

struct SearchCardView: View {
    @Binding var selectedDate: Date?
    @Binding var selectedClubIds: Set<String>
    @Binding var minDistanceKm: Double
    @Binding var maxDistanceKm: Double
    @Binding var requiresRoute: Bool
    @Binding var endDate: Date?
    @Binding var flexibility: DateFlexibility
    let clubs: [Club]
    let favorites: FavoritesManager
    let onSearch: () -> Void
    @Environment(AppSettings.self) private var appSettings
    @State private var showClubPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Find a Run")
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
            }
            .foregroundStyle(.primary)

            Divider()

            // Date picker
            RunDatePickerView(
                startDate: $selectedDate,
                endDate: $endDate,
                flexibility: $flexibility,
                onNext: onSearch,
                onReset: {
                    selectedDate = nil
                    endDate = nil
                    flexibility = .exact
                }
            )

            Divider()

            // Club filter — multi-select
            VStack(alignment: .leading, spacing: 6) {
                Label("Clubs", systemImage: "person.3.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Button {
                    showClubPicker = true
                } label: {
                    HStack {
                        if selectedClubIds.isEmpty {
                            Text("All Clubs")
                                .foregroundStyle(.primary)
                        } else {
                            Text("\(selectedClubIds.count) club\(selectedClubIds.count == 1 ? "" : "s") selected")
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            // Distance filter — slider
            DistanceRangeFilter(minKm: $minDistanceKm, maxKm: $maxDistanceKm)

            Divider()

            // Route map filter
            Toggle(isOn: $requiresRoute) {
                Label("Has Route Map", systemImage: "map")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            

            Divider()

            // Reset + Search row
            HStack {
                Button("Reset") {
                    selectedDate = nil
                    endDate = nil
                    flexibility = .exact
                    selectedClubIds = []
                    minDistanceKm = 0
                    maxDistanceKm = 50
                    requiresRoute = false
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: onSearch) {
                    Text("Search")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(appSettings.themeColor, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .sheet(isPresented: $showClubPicker) {
            ClubPickerView(
                clubs: clubs,
                selectedIds: $selectedClubIds,
                favorites: favorites
            )
        }
    }
}

// MARK: - Distance Range Slider

struct DistanceRangeFilter: View {
    @Binding var minKm: Double
    @Binding var maxKm: Double
    @Environment(AppSettings.self) private var appSettings

    private let steps: [Double] = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
    private let thumbR: CGFloat = 13
    private let trackH: CGFloat = 4
    @State private var draggingMin = true

    private var minIdx: Int { steps.firstIndex(of: minKm) ?? 0 }
    private var maxIdx: Int { steps.firstIndex(of: maxKm) ?? steps.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Distance", systemImage: "ruler")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(rangeLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(appSettings.themeColor)
            }

            GeometryReader { geo in
                let trackW = geo.size.width - thumbR * 2
                let step = trackW / Double(steps.count - 1)
                let minX = thumbR + Double(minIdx) * step
                let maxX = thumbR + Double(maxIdx) * step

                ZStack(alignment: .leading) {
                    // Gray background track
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: trackH)
                        .padding(.horizontal, thumbR)

                    // Orange fill between thumbs
                    Rectangle()
                        .fill(appSettings.themeColor)
                        .frame(width: max(0, maxX - minX), height: trackH)
                        .offset(x: minX)

                    // Min thumb
                    thumbView.offset(x: minX - thumbR)

                    // Max thumb
                    thumbView.offset(x: maxX - thumbR)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let x = val.location.x
                            // Determine which thumb to drag on first touch
                            if abs(val.translation.width) + abs(val.translation.height) < 2 {
                                draggingMin = abs(x - minX) <= abs(x - maxX)
                            }
                            let raw = Int(((x - thumbR) / step).rounded())
                            if draggingMin {
                                minKm = steps[max(0, min(raw, maxIdx))]
                            } else {
                                maxKm = steps[max(minIdx, min(raw, steps.count - 1))]
                            }
                        }
                )
            }
            .frame(height: thumbR * 2 + 4)
        }
    }

    private var thumbView: some View {
        Circle()
            .fill(.white)
            .frame(width: thumbR * 2, height: thumbR * 2)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .overlay(Circle().stroke(appSettings.themeColor, lineWidth: 2))
    }

    private var rangeLabel: String {
        let lo = minKm == 0 ? "Any" : "\(Int(minKm)) km"
        let hi = maxKm >= 50 ? "50+ km" : "\(Int(maxKm)) km"
        return minKm == 0 ? hi : "\(lo) – \(hi)"
    }
}

// MARK: - Club Picker with multi-select and favorites

struct ClubPickerView: View {
    let clubs: [Club]
    @Binding var selectedIds: Set<String>
    let favorites: FavoritesManager
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        NavigationStack {
            List(clubs) { club in
                HStack {
                    Button {
                        favorites.toggle(club.id)
                    } label: {
                        Image(systemName: favorites.isFavorite(club.id) ? "star.fill" : "star")
                            .foregroundStyle(favorites.isFavorite(club.id) ? .yellow : appSettings.themeColor)
                    }
                    .buttonStyle(.plain)

                    Text(club.name)
                        .font(.subheadline)

                    Spacer()

                    Image(systemName: selectedIds.contains(club.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIds.contains(club.id) ? appSettings.themeColor : Color(.tertiaryLabel))
                        .font(.title3)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedIds.contains(club.id) {
                        selectedIds.remove(club.id)
                    } else {
                        selectedIds.insert(club.id)
                    }
                }
            }
            .navigationTitle("Select Clubs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        selectedIds.removeAll()
                    }
                    
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        
                }
            }
        }
    }
}
