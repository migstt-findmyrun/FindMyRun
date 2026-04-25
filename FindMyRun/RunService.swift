//
//  RunService.swift
//  FindMyRun
//

import Foundation
import CoreLocation

enum DistanceFilter: String, CaseIterable, Identifiable {
    case any = "Any"
    case short = "< 5 km"
    case medium = "5–10 km"
    case long = "10+ km"

    var id: String { rawValue }
}

@Observable
final class RunService {
    var runs: [Run] = []
    private(set) var clubs: [Club] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let supabaseURL = "https://fznbkrpgfhfeahkdehps.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ6bmJrcnBnZmhmZWFoa2RlaHBzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NjQwNzksImV4cCI6MjA5MTM0MDA3OX0.0jqRCvcWHAlqSAh0b8xhARjRI-8TepHmTJJU4i2Wy0o"

    func fetchClubs() async {
        let urlString = "\(supabaseURL)/rest/v1/clubs?select=*&admin_down=eq.false&order=name.asc"

        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                print("fetchClubs error \(http.statusCode): \(body)")
                return
            }
            clubs = try JSONDecoder().decode([Club].self, from: data)
        } catch {
            print("fetchClubs decode error: \(error)")
        }
    }

    func searchRuns(date: Date?, endDate: Date? = nil, clubIds: Set<String> = [], minKm: Double = 0, maxKm: Double = 0, requiresRoute: Bool = false, nearLocation: CLLocationCoordinate2D? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var queryParams = "select=*,clubs(*),routes(*)&order=occurs_at.asc"

        let formatter = ISO8601DateFormatter()
        let now = Date()

        if let date = date {
            let lowerBound = max(Calendar.current.startOfDay(for: date), now)
            queryParams += "&occurs_at=gte.\(formatter.string(from: lowerBound))"

            if let end = endDate {
                // Range search: up to end of the end date
                let endOfEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end)) ?? end
                queryParams += "&occurs_at=lt.\(formatter.string(from: endOfEnd))"
            } else {
                // Single day: cap at end of that day
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date
                queryParams += "&occurs_at=lt.\(formatter.string(from: endOfDay))"
            }
        } else {
            queryParams += "&occurs_at=gte.\(formatter.string(from: now))"
        }

        // Filter: clubs (multi-select)
        if !clubIds.isEmpty {
            let ids = clubIds.joined(separator: ",")
            queryParams += "&club_id=in.(\(ids))"
        }

        // Filter: has route
        if requiresRoute {
            queryParams += "&route_id=not.is.null"
        }

        let urlString = "\(supabaseURL)/rest/v1/events?\(queryParams)"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Server error"
                return
            }

            let decoder = JSONDecoder()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let d = isoFormatter.date(from: dateString) { return d }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let d = isoFormatter.date(from: dateString) { return d }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            var results = try decoder.decode([Run].self, from: data)

            // Client-side distance range filter
            if minKm > 0 || maxKm < 50 {
                let minMeters = minKm * 1000
                let maxMeters = maxKm >= 50 ? Double.infinity : maxKm * 1000
                results = results.filter {
                    guard let d = $0.routes?.distanceMeters else { return false }
                    return d >= minMeters && d <= maxMeters
                }
            }

            // Client-side proximity filter (100 km radius from custom location)
            if let origin = nearLocation {
                let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                results = results.filter { run in
                    let lat = run.startLat ?? run.clubs.latitude
                    let lng = run.startLng ?? run.clubs.longitude
                    guard let lat, let lng else { return false }
                    let runLocation = CLLocation(latitude: lat, longitude: lng)
                    return originLocation.distance(from: runLocation) <= 25_000
                }
            }

            runs = results
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetch upcoming runs near a location, filtered by radius in km
    func fetchNearbyRuns(latitude: Double, longitude: Double, radiusKm: Double) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())

        let queryParams = "select=*,clubs(*),routes(*)&occurs_at=gte.\(now)&order=occurs_at.asc"
        let urlString = "\(supabaseURL)/rest/v1/events?\(queryParams)"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Server error"
                return
            }

            let decoder = JSONDecoder()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let d = isoFormatter.date(from: dateString) { return d }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let d = isoFormatter.date(from: dateString) { return d }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            let allRuns = try decoder.decode([Run].self, from: data)

            let center = CLLocation(latitude: latitude, longitude: longitude)
            runs = allRuns.filter { run in
                // Keep runs with no coordinates — they'll be placed via club city geocoding
                guard let lat = run.startLat, let lng = run.startLng else { return true }
                let runLocation = CLLocation(latitude: lat, longitude: lng)
                return center.distance(from: runLocation) <= radiusKm * 1000
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetch a single club by its UUID
    func fetchClub(id: String) async -> Club? {
        let urlString = "\(supabaseURL)/rest/v1/clubs?id=eq.\(id)&select=*&limit=1"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode([Club].self, from: data).first
        } catch {
            return nil
        }
    }

    /// Fetch a single run by its UUID
    func fetchRun(id: String) async -> Run? {
        let urlString = "\(supabaseURL)/rest/v1/events?id=eq.\(id)&select=*,clubs(*),routes(*)&limit=1"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            let decoder = JSONDecoder()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let d = isoFormatter.date(from: dateString) { return d }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let d = isoFormatter.date(from: dateString) { return d }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            return try decoder.decode([Run].self, from: data).first
        } catch {
            return nil
        }
    }

    /// Fetch all upcoming runs in chronological order
    func fetchAllUpcoming() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())

        let queryParams = "select=*,clubs(*),routes(*)&occurs_at=gte.\(now)&order=occurs_at.asc"
        let urlString = "\(supabaseURL)/rest/v1/events?\(queryParams)"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Server error"
                return
            }

            let decoder = JSONDecoder()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let d = isoFormatter.date(from: dateString) { return d }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let d = isoFormatter.date(from: dateString) { return d }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            runs = try decoder.decode([Run].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
