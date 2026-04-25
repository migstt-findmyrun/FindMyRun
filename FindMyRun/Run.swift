//
//  Run.swift
//  FindMyRun
//

import Foundation
import CoreLocation

struct Run: Identifiable, Codable, Hashable {
    static func == (lhs: Run, rhs: Run) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String
    let stravaEventId: String
    let title: String
    let description: String?
    let address: String?
    let startLat: Double?
    let startLng: Double?
    let activityType: String?
    let skillLevel: Int?
    let womenOnly: Bool
    let timezone: String?
    let organizingAthlete: String?
    let occursAt: Date
    let clubs: Club
    let routes: Route?

    enum CodingKeys: String, CodingKey {
        case id
        case stravaEventId = "strava_event_id"
        case title
        case description
        case address
        case startLat = "start_lat"
        case startLng = "start_lng"
        case activityType = "activity_type"
        case skillLevel = "skill_level"
        case womenOnly = "women_only"
        case timezone
        case organizingAthlete = "organizing_athlete"
        case occursAt = "occurs_at"
        case clubs
        case routes
    }
}

struct Club: Identifiable, Codable {
    let id: String
    let name: String
    let slug: String?
    let city: String?
    let state: String?
    let country: String?
    let stravaId: Int?
    let memberCount: Int?
    let description: String?
    let website: String?
    let latitude: Double?
    let longitude: Double?
    let adminDown: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, slug, city, state, country, description, website, latitude, longitude
        case stravaId = "strava_id"
        case memberCount = "member_count"
        case adminDown = "admin_down"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        slug        = try c.decodeIfPresent(String.self, forKey: .slug)
        city        = try c.decodeIfPresent(String.self, forKey: .city)
        state       = try c.decodeIfPresent(String.self, forKey: .state)
        country     = try c.decodeIfPresent(String.self, forKey: .country)
        stravaId    = try c.decodeIfPresent(Int.self, forKey: .stravaId)
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        website     = try c.decodeIfPresent(String.self, forKey: .website)
        latitude    = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude   = try c.decodeIfPresent(Double.self, forKey: .longitude)
        adminDown   = (try? c.decode(Bool.self, forKey: .adminDown)) ?? false
    }

    var stravaURL: URL? {
        if let id = stravaId {
            return URL(string: "https://www.strava.com/clubs/\(id)")
        } else if let slug {
            return URL(string: "https://www.strava.com/clubs/\(slug)")
        }
        return nil
    }
}

extension Run {
    func distanceMeters(from userCoord: CLLocationCoordinate2D) -> Double? {
        let lat = startLat ?? clubs.latitude
        let lng = startLng ?? clubs.longitude
        guard let lat, let lng else { return nil }
        return CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
            .distance(from: CLLocation(latitude: lat, longitude: lng))
    }
}

extension Array where Element == Run {
    /// Sort by date (day) first, then by distance from the user's location within the same day.
    /// Runs with no known coordinates sort to the end of their date group.
    func sortedByDateThenDistance(from userLocation: CLLocationCoordinate2D?) -> [Run] {
        let cal = Calendar.current
        return sorted { a, b in
            let dayA = cal.startOfDay(for: a.occursAt)
            let dayB = cal.startOfDay(for: b.occursAt)
            guard dayA == dayB else { return dayA < dayB }
            guard let userCoord = userLocation else { return false }
            switch (a.distanceMeters(from: userCoord), b.distanceMeters(from: userCoord)) {
            case (nil, nil):        return false
            case (nil, _):          return false
            case (_, nil):          return true
            case let (da?, db?):    return da < db
            }
        }
    }
}

struct Route: Identifiable, Codable {
    let id: String
    let name: String?
    let distanceMeters: Double?
    let elevationGainMeters: Double?
    let estimatedMovingTimeSecs: Int?
    let summaryPolyline: String?
    let polyline: String?

    enum CodingKeys: String, CodingKey {
        case id, name, polyline
        case distanceMeters = "distance_meters"
        case elevationGainMeters = "elevation_gain_meters"
        case estimatedMovingTimeSecs = "estimated_moving_time_secs"
        case summaryPolyline = "summary_polyline"
    }

    var distanceKm: String? {
        guard let distanceMeters else { return nil }
        return String(format: "%.1f km", distanceMeters / 1000)
    }

    var elevationFormatted: String? {
        guard let elevationGainMeters else { return nil }
        return String(format: "%.0f m", elevationGainMeters)
    }

    var estimatedTimeFormatted: String? {
        guard let estimatedMovingTimeSecs else { return nil }
        let minutes = estimatedMovingTimeSecs / 60
        return "\(minutes) min"
    }
}
