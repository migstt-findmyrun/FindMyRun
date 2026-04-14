//
//  Athlete.swift
//  FindMyRun
//

import Foundation

struct StravaTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let athlete: AthleteProfile?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }
}

struct AthleteProfile: Codable {
    let id: Int
    let firstname: String?
    let lastname: String?
    let profile: String?  // avatar URL
    let city: String?
    let state: String?
    let country: String?

    var displayName: String {
        [firstname, lastname].compactMap { $0 }.joined(separator: " ")
    }
}

struct AthleteStats: Codable {
    let recentRunTotals: ActivityTotal?
    let allRunTotals: ActivityTotal?
    let ytdRunTotals: ActivityTotal?

    enum CodingKeys: String, CodingKey {
        case recentRunTotals = "recent_run_totals"
        case allRunTotals = "all_run_totals"
        case ytdRunTotals = "ytd_run_totals"
    }
}

struct ActivityTotal: Codable {
    let count: Int?
    let distance: Double?        // meters
    let movingTime: Int?         // seconds
    let elapsedTime: Int?        // seconds
    let elevationGain: Double?   // meters

    enum CodingKeys: String, CodingKey {
        case count, distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case elevationGain = "elevation_gain"
    }

    /// Average pace in min/km
    var averagePace: String? {
        guard let distance, distance > 0, let movingTime, movingTime > 0 else { return nil }
        let paceSecondsPerKm = Double(movingTime) / (distance / 1000)
        let mins = Int(paceSecondsPerKm) / 60
        let secs = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }

    var distanceKm: String? {
        guard let distance, distance > 0 else { return nil }
        return String(format: "%.1f km", distance / 1000)
    }
}
