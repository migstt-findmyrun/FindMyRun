//
//  SharedRunStore.swift
//  FindMyRun
//
//  Shared between the main app and the widget extension.
//  After creating this file, select it in Xcode → File Inspector →
//  Target Membership → check both FindMyRun and FindMyRunWidget.
//

import Foundation

// Lightweight run data written by the main app, read by the widget.
struct WidgetRun: Codable, Identifiable {
    let id: String
    let title: String
    let clubName: String
    let clubCity: String?
    let occursAt: Date
    let address: String?
    let distanceKm: String?
    let polyline: String?
}

// Passed from Siri intent → ContentView → SearchPageView
struct SiriSearchRequest: Codable {
    let city: String?
    let startDate: Date
    let endDate: Date
    let minKm: Double?
    let maxKm: Double?
}

enum SharedRunStore {
    static let appGroupID = "group.app.findmyrun"
    private static let runsKey = "widgetSavedRuns"

    static func save(_ runs: [WidgetRun]) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let data = try? JSONEncoder().encode(runs) {
            defaults.set(data, forKey: runsKey)
        }
    }

    static func saveSiriRequest(_ request: SiriSearchRequest) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(request) else { return }
        defaults.set(data, forKey: "siriSearchRequest")
        defaults.set("search", forKey: "siriRequestedTab")
    }

    static func loadSiriRequest() -> SiriSearchRequest? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: "siriSearchRequest"),
              let req = try? JSONDecoder().decode(SiriSearchRequest.self, from: data) else { return nil }
        defaults.removeObject(forKey: "siriSearchRequest")
        return req
    }

    static func load() -> [WidgetRun] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: runsKey),
              let runs = try? JSONDecoder().decode([WidgetRun].self, from: data)
        else { return [] }
        return runs
    }
}
