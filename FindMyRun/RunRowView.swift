//
//  RunRowView.swift
//  FindMyRun
//

import SwiftUI
import CoreLocation

struct RunRowView: View {
    let run: Run
    var forecast: DayForecast? = nil
    var isFetchingForecast: Bool = false
    var onClubInfoTapped: ((Club) -> Void)? = nil
    @Environment(LocationService.self) private var locationService
    @Environment(FavoritesManager.self) private var favorites
    @Environment(AppSettings.self) private var appSettings

    private var distanceToStart: String? {
        guard let userCoord = locationService.location else { return nil }
        let lat = run.startLat ?? run.clubs.latitude
        let lng = run.startLng ?? run.clubs.longitude
        guard let lat, let lng else { return nil }
        let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let runLoc = CLLocation(latitude: lat, longitude: lng)
        let metres = userLoc.distance(from: runLoc)
        return metres < 1000
            ? String(format: "%.0f m away", metres)
            : String(format: "%.1f km away", metres / 1000)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.title)
                        .font(.headline)
                        .fontDesign(.rounded)

                    HStack(spacing: 4) {
                        Text(run.clubs.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            onClubInfoTapped?(run.clubs)
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(appSettings.themeColor.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Text(run.occursAt, format: .dateTime.weekday(.abbreviated))
                    .font(.caption)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(appSettings.themeColor.gradient, in: Capsule())
            }

            HStack(spacing: 14) {
                Label(run.occursAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")

                if let distance = run.routes?.distanceKm {
                    Label(distance, systemImage: "figure.run")
                }

                if let elevation = run.routes?.elevationFormatted {
                    Label(elevation, systemImage: "mountain.2")
                }

                if let time = run.routes?.estimatedTimeFormatted {
                    Label(time, systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                if let address = run.address {
                    Label(address, systemImage: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if let distance = distanceToStart {
                    Spacer()
                    Label(distance, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(appSettings.themeColor)
                }
            }

            if let forecast {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: forecast.conditionIcon)
                        .symbolRenderingMode(.multicolor)
                    Text(forecast.conditionName)
                        .fontWeight(.semibold)
                    Text(forecast.tempRange)
                        .foregroundStyle(.secondary)
                    if let precip = forecast.precipitationProbability, precip > 0 {
                        Spacer()
                        Label("\(precip)% rain", systemImage: "drop.fill")
                            .foregroundStyle(.cyan)
                    }
                }
                .font(.caption)
                HStack(spacing: 3) {
                    Image(systemName: "apple.logo")
                    Text("Weather")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            } else if isFetchingForecast {
                Divider()
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Loading forecast…")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}
