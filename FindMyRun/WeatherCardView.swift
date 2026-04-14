//
//  WeatherCardView.swift
//  FindMyRun
//

import SwiftUI

struct WeatherCardView: View {
    let weather: CurrentWeather

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Right Now")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(weather.temperature))°")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("C")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)

                    Text(weather.conditionName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                Image(systemName: weather.conditionIcon)
                    .font(.system(size: 56))
                    .symbolRenderingMode(.multicolor)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }

            Divider()
                .overlay(.white.opacity(0.3))

            HStack(spacing: 20) {
                WeatherDetail(icon: "thermometer.medium", label: "Feels", value: "\(Int(weather.apparentTemperature))°")
                WeatherDetail(icon: "wind", label: "Wind", value: "\(Int(weather.windSpeed)) km/h")
                WeatherDetail(icon: "humidity.fill", label: "Humidity", value: "\(weather.humidity)%")
            }

            Text(weather.runningVibes)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .padding(20)
        .background(weatherGradient, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: gradientColors.0.opacity(0.3), radius: 10, y: 5)
    }

    private var gradientColors: (Color, Color) {
        switch weather.weatherCode {
        case 0, 1: return (.orange, .pink)
        case 2, 3: return (.blue, .indigo)
        case 45, 48: return (.gray, .blue)
        case 51...67: return (.cyan, .blue)
        case 71...86: return (.blue, .purple)
        case 95, 96, 99: return (.indigo, .purple)
        default: return (.blue, .cyan)
        }
    }

    private var weatherGradient: LinearGradient {
        LinearGradient(
            colors: [gradientColors.0, gradientColors.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct WeatherDetail: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            VStack(spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption2)
            }
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}
