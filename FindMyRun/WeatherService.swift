//
//  WeatherService.swift
//  FindMyRun
//

import Foundation

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

    /// Suggests whether it's a good day for running
    var runningVibes: String {
        switch weatherCode {
        case 0, 1:
            if temperature < 0 { return "Bundle up and hit the road!" }
            if temperature > 30 { return "Hot one — hydrate extra!" }
            return "Perfect running weather!"
        case 2, 3:
            return "Great day for a run!"
        case 45, 48:
            return "Mysterious fog run vibes"
        case 51, 53, 55:
            return "Light drizzle — embrace it!"
        case 61, 63, 65, 80, 81, 82:
            return "Rainy run — you'll feel alive!"
        case 66, 67, 71, 73, 75, 77, 85, 86:
            return "Brave the snow — legend status!"
        case 95, 96, 99:
            return "Maybe wait this one out..."
        default:
            return "Get out there!"
        }
    }
}

struct DayForecast: Codable {
    let weatherCode: Int
    let temperatureMax: Double
    let temperatureMin: Double
    let precipitationProbability: Int?

    /// Color for the route polyline based on forecast conditions
    var routeColor: RouteWeatherColor {
        switch weatherCode {
        case 0, 1: // Clear
            if temperatureMax > 30 { return .hot }
            if temperatureMin < -5 { return .freezing }
            return .clear
        case 2, 3: // Cloudy
            return .cloudy
        case 45, 48: // Fog
            return .fog
        case 51, 53, 55: // Drizzle
            return .lightRain
        case 61, 63, 65, 80, 81, 82: // Rain
            return .rain
        case 66, 67: // Freezing rain
            return .freezingRain
        case 71, 73, 75, 77, 85, 86: // Snow
            return .snow
        case 95, 96, 99: // Thunderstorm
            return .storm
        default:
            return .clear
        }
    }

    var conditionName: String {
        switch weatherCode {
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Showers"
        case 85, 86: return "Snow Showers"
        case 95, 96, 99: return "Thunderstorm"
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

    var tempRange: String {
        "\(Int(temperatureMin))° – \(Int(temperatureMax))°C"
    }
}

enum RouteWeatherColor: String {
    case clear, cloudy, fog, lightRain, rain, freezingRain, snow, storm, hot, freezing

    var primary: String {
        switch self {
        case .clear: return "routeClear"
        case .cloudy: return "routeCloudy"
        case .fog: return "routeFog"
        case .lightRain: return "routeLightRain"
        case .rain: return "routeRain"
        case .freezingRain: return "routeFreezingRain"
        case .snow: return "routeSnow"
        case .storm: return "routeStorm"
        case .hot: return "routeHot"
        case .freezing: return "routeFreezing"
        }
    }
}

private struct WeatherResponse: Codable {
    let currentWeather: CurrentWeather

    enum CodingKeys: String, CodingKey {
        case currentWeather = "current"
    }
}

private struct ForecastResponse: Codable {
    let daily: DailyData

    struct DailyData: Codable {
        let time: [String]
        let weatherCode: [Int]
        let temperatureMax: [Double]
        let temperatureMin: [Double]
        let precipitationProbabilityMax: [Int]?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
            case precipitationProbabilityMax = "precipitation_probability_max"
        }
    }
}

@Observable
final class WeatherService {
    private(set) var weather: CurrentWeather?
    private(set) var isLoading = false

    // Default to Toronto
    func fetchWeather(latitude: Double = 43.6532, longitude: Double = -79.3832) async {
        isLoading = true
        defer { isLoading = false }

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m&timezone=auto"

        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
            weather = response.currentWeather
        } catch {
            // Silently fail — weather is supplementary
        }
    }

    /// Fetch forecast for a specific date and location
    static func fetchForecast(for date: Date, latitude: Double, longitude: Double) async -> DayForecast? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&start_date=\(dateString)&end_date=\(dateString)&timezone=auto"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ForecastResponse.self, from: data)

            guard let daily = response.daily.weatherCode.first,
                  let tempMax = response.daily.temperatureMax.first,
                  let tempMin = response.daily.temperatureMin.first else { return nil }

            return DayForecast(
                weatherCode: daily,
                temperatureMax: tempMax,
                temperatureMin: tempMin,
                precipitationProbability: response.daily.precipitationProbabilityMax?.first
            )
        } catch {
            return nil
        }
    }
}
