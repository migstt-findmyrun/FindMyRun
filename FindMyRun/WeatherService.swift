//
//  WeatherService.swift
//  FindMyRun
//

import Foundation
import CoreLocation
import WeatherKit

// MARK: - Current Weather (Open-Meteo, used by WeatherCardView)

struct CurrentWeather: Codable {
    let temperature: Double
    let apparentTemperature: Double
    let weatherCode: Int
    let windSpeed: Double
    let humidity: Int

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case weatherCode = "weather_code"
        case windSpeed = "wind_speed_10m"
        case humidity = "relative_humidity_2m"
    }

    var conditionName: String {
        switch weatherCode {
        case 0: return "Clear Sky"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rainy"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snowy"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Hail Storm"
        default: return "Unknown"
        }
    }

    var conditionIcon: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1: return "sun.min.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }

    var runningVibes: String {
        switch weatherCode {
        case 0, 1:
            if temperature < 0 { return "Bundle up and hit the road!" }
            if temperature > 30 { return "Hot one — hydrate extra!" }
            return "Perfect running weather!"
        case 2, 3: return "Great day for a run!"
        case 45, 48: return "Mysterious fog run vibes"
        case 51, 53, 55: return "Light drizzle — embrace it!"
        case 61, 63, 65, 80, 81, 82: return "Rainy run — you'll feel alive!"
        case 66, 67, 71, 73, 75, 77, 85, 86: return "Brave the snow — legend status!"
        case 95, 96, 99: return "Maybe wait this one out..."
        default: return "Get out there!"
        }
    }
}

// MARK: - Day Forecast (WeatherKit)

struct DayForecast {
    let temperatureMax: Double
    let temperatureMin: Double
    let precipitationProbability: Int?
    let conditionName: String
    let conditionIcon: String
    let routeColor: RouteWeatherColor

    var tempRange: String {
        if Int(temperatureMin) == Int(temperatureMax) {
            return "\(Int(temperatureMax))°C"
        }
        return "\(Int(temperatureMin))° – \(Int(temperatureMax))°C"
    }
}

// MARK: - Route Weather Colour

enum RouteWeatherColor: String {
    case clear, cloudy, fog, lightRain, rain, freezingRain, snow, storm, hot, freezing

    var primary: String {
        switch self {
        case .clear:        return "routeClear"
        case .cloudy:       return "routeCloudy"
        case .fog:          return "routeFog"
        case .lightRain:    return "routeLightRain"
        case .rain:         return "routeRain"
        case .freezingRain: return "routeFreezingRain"
        case .snow:         return "routeSnow"
        case .storm:        return "routeStorm"
        case .hot:          return "routeHot"
        case .freezing:     return "routeFreezing"
        }
    }
}

// MARK: - Weather Service

final class WeatherService {
    /// Fetches an hourly forecast for a specific date/time and location using WeatherKit.
    static func fetchForecast(for date: Date, latitude: Double, longitude: Double) async -> DayForecast? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let forecast = try await WeatherKit.WeatherService.shared.weather(
                for: location, including: .hourly
            )
            guard let hour = forecast.forecast.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }) else { return nil }
            let tempC = hour.temperature.converted(to: .celsius).value
            let precip = Int((hour.precipitationChance * 100).rounded())
            return DayForecast(
                temperatureMax: tempC,
                temperatureMin: tempC,
                precipitationProbability: precip,
                conditionName: label(for: hour.condition),
                conditionIcon: hour.symbolName,
                routeColor: routeColor(for: hour.condition, maxTemp: tempC, minTemp: tempC)
            )
        } catch {
            return nil
        }
    }

    // MARK: - WeatherKit condition helpers

    private static func label(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear:                    return "Clear"
        case .mostlyClear:              return "Mostly Clear"
        case .partlyCloudy:             return "Partly Cloudy"
        case .mostlyCloudy:             return "Mostly Cloudy"
        case .cloudy:                   return "Cloudy"
        case .foggy:                    return "Foggy"
        case .haze:                     return "Hazy"
        case .smoky:                    return "Smoky"
        case .blowingDust:              return "Blowing Dust"
        case .drizzle:                  return "Drizzle"
        case .freezingDrizzle:          return "Freezing Drizzle"
        case .rain:                     return "Rain"
        case .heavyRain:                return "Heavy Rain"
        case .sunShowers:               return "Sun Showers"
        case .freezingRain:             return "Freezing Rain"
        case .sleet:                    return "Sleet"
        case .wintryMix:                return "Wintry Mix"
        case .snow:                     return "Snow"
        case .heavySnow:                return "Heavy Snow"
        case .flurries:                 return "Flurries"
        case .sunFlurries:              return "Sun Flurries"
        case .blowingSnow:              return "Blowing Snow"
        case .blizzard:                 return "Blizzard"
        case .thunderstorms:            return "Thunderstorm"
        case .isolatedThunderstorms:    return "Isolated Storms"
        case .scatteredThunderstorms:   return "Scattered Storms"
        case .strongStorms:             return "Strong Storms"
        case .breezy:                   return "Breezy"
        case .windy:                    return "Windy"
        case .hail:                     return "Hail"
        case .hot:                      return "Hot"
        case .frigid:                   return "Frigid"
        case .hurricane:                return "Hurricane"
        case .tropicalStorm:            return "Tropical Storm"
        @unknown default:               return "Unknown"
        }
    }

    private static func routeColor(for condition: WeatherCondition, maxTemp: Double, minTemp: Double) -> RouteWeatherColor {
        switch condition {
        case .clear, .mostlyClear:
            if maxTemp > 30 { return .hot }
            if minTemp < -5 { return .freezing }
            return .clear
        case .hot:                      return .hot
        case .frigid:                   return .freezing
        case .partlyCloudy, .mostlyCloudy, .cloudy, .breezy, .windy:
            return .cloudy
        case .foggy, .haze, .smoky, .blowingDust:
            return .fog
        case .drizzle, .sunShowers:     return .lightRain
        case .rain, .heavyRain, .freezingDrizzle:
            return .rain
        case .freezingRain, .sleet, .wintryMix:
            return .freezingRain
        case .snow, .heavySnow, .flurries, .sunFlurries, .blowingSnow, .blizzard:
            return .snow
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms,
             .strongStorms, .hurricane, .tropicalStorm, .hail:
            return .storm
        @unknown default:               return .clear
        }
    }
}
