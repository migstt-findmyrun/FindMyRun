//
//  AppIntents.swift
//  FindMyRun
//

import AppIntents
import Foundation
import CoreLocation
import MapKit

// MARK: - Show Next Run
// Runs in background — Siri speaks the result without opening the app.

struct ShowNextRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Next Run"
    static var description = IntentDescription("Tells you about your next upcoming saved run.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let allRuns: [WidgetRun] = await MainActor.run { SharedRunStore.load() }
        let next = allRuns
            .filter { $0.occursAt > Date() }
            .sorted { $0.occursAt < $1.occursAt }
            .first

        guard let next else {
            return .result(dialog: "You don't have any upcoming saved runs in FindMyRun.")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let when = formatter.localizedString(for: next.occursAt, relativeTo: Date())

        return .result(
            dialog: "Your next run is \(next.title) with \(next.clubName), \(when)."
        )
    }
}

// MARK: - Open My Runs
// Opens the app and navigates to the My Runs tab.

struct OpenMyRunsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open My Runs"
    static var description = IntentDescription("Opens your saved runs in FindMyRun.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let groupID: String = await MainActor.run { SharedRunStore.appGroupID }
        UserDefaults(suiteName: groupID)?.set("myRuns", forKey: "siriRequestedTab")
        return .result(dialog: "Opening your saved runs.")
    }
}

// MARK: - Date Range Option

enum DateRangeOption: String, AppEnum {
    case today, tomorrow, nextFewDays, thisWeek, thisWeekend

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Time Frame"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .today:       "Today",
        .tomorrow:    "Tomorrow",
        .nextFewDays: "Next Few Days",
        .thisWeek:    "This Week",
        .thisWeekend: "This Weekend"
    ]

    var label: String {
        switch self {
        case .today:       return "today's"
        case .tomorrow:    return "tomorrow's"
        case .nextFewDays: return "upcoming"
        case .thisWeek:    return "this week's"
        case .thisWeekend: return "this weekend's"
        }
    }

    var startDate: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch self {
        case .today:       return today
        case .tomorrow:    return cal.date(byAdding: .day, value: 1, to: today)!
        case .nextFewDays: return today
        case .thisWeek:    return today
        case .thisWeekend: return nextWeekday(7, from: today, using: cal) // Saturday (weekday 7)
        }
    }

    var endDate: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch self {
        case .today:       return today
        case .tomorrow:    return cal.date(byAdding: .day, value: 1, to: today)!
        case .nextFewDays: return cal.date(byAdding: .day, value: 3, to: today)!
        case .thisWeek:    return cal.date(byAdding: .day, value: 7, to: today)!
        case .thisWeekend: return nextWeekday(1, from: today, using: cal) // Sunday (weekday 1)
        }
    }

    // Returns the next occurrence of a given weekday (1=Sun … 7=Sat).
    private func nextWeekday(_ target: Int, from date: Date, using cal: Calendar) -> Date {
        let current = cal.component(.weekday, from: date)
        let daysAhead = (target - current + 7) % 7
        return cal.date(byAdding: .day, value: daysAhead == 0 ? 7 : daysAhead, to: date)!
    }
}

// MARK: - Find Runs

struct FindRunsIntent: AppIntent {
    static var title: LocalizedStringResource = "Find a Run"
    static var description = IntentDescription("Search for upcoming group runs by location, date, and distance.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "City",
               description: "The city to search in. Leave blank to use your current location.",
               requestValueDialog: "Which city would you like to run in?")
    var city: String?

    @Parameter(title: "When",
               description: "How soon do you want to run?",
               default: .nextFewDays,
               requestValueDialog: "When would you like to run?")
    var dateRange: DateRangeOption

    @Parameter(title: "Minimum Distance (km)",
               description: "The shortest run distance you're interested in.",
               requestValueDialog: "What's the minimum distance in km?")
    var minDistanceKm: Double?

    @Parameter(title: "Maximum Distance (km)",
               description: "The longest run distance you're interested in.",
               requestValueDialog: "What's the maximum distance in km?")
    var maxDistanceKm: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("Find a \(\.$dateRange) run in \(\.$city)") {
            \.$minDistanceKm
            \.$maxDistanceKm
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Geocode city if provided
        var searchCoord: CLLocationCoordinate2D? = nil
        if let city, !city.isEmpty {
            searchCoord = await geocode(city)
        }

        // 2. Fetch all upcoming runs from the API
        let allRuns = await fetchUpcomingRuns()

        // 3. Filter by date range
        let cal = Calendar.current
        let start = dateRange.startDate
        let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: dateRange.endDate)!
        var filtered = allRuns.filter { $0.occursAt >= start && $0.occursAt <= end }

        // 4. Filter by location (50 km radius)
        if let coord = searchCoord {
            let center = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            filtered = filtered.filter { run in
                let lat = run.startLat ?? run.clubs.latitude
                let lng = run.startLng ?? run.clubs.longitude
                guard let lat, let lng else { return true }
                return CLLocation(latitude: lat, longitude: lng).distance(from: center) <= 50_000
            }
        }

        // 5. Filter by distance range
        if let min = minDistanceKm {
            filtered = filtered.filter { ($0.routes?.distanceMeters).map { $0 / 1000 >= min } ?? true }
        }
        if let max = maxDistanceKm {
            filtered = filtered.filter { ($0.routes?.distanceMeters).map { $0 / 1000 <= max } ?? true }
        }

        // 6. Save search request so the app pre-populates the Search tab on open
        let request = SiriSearchRequest(
            city: city,
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
            minKm: minDistanceKm,
            maxKm: maxDistanceKm
        )
        await MainActor.run { SharedRunStore.saveSiriRequest(request) }

        // 7. Build spoken response
        let cityDesc = city.map { " in \($0)" } ?? ""
        let count = filtered.count

        guard count > 0 else {
            return .result(dialog: "I couldn't find any \(dateRange.label) runs\(cityDesc). Try a different location or time frame. Opening FindMyRun.")
        }

        let soonest = filtered.sorted { $0.occursAt < $1.occursAt }.first!
        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .full
        let when = relFormatter.localizedString(for: soonest.occursAt, relativeTo: Date())
        let distanceDesc: String = {
            guard let meters = soonest.routes?.distanceMeters else { return "" }
            return String(format: ", %.1f km", meters / 1000)
        }()
        let countWord = count == 1 ? "1 run" : "\(count) runs"

        return .result(dialog: "I found \(countWord)\(cityDesc) for \(dateRange.label). The soonest is \(soonest.title) with \(soonest.clubs.name)\(distanceDesc), \(when). Opening FindMyRun.")
    }

    // MARK: - Helpers

    private func geocode(_ city: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = city
        request.resultTypes = .address
        let items = try? await MKLocalSearch(request: request).start().mapItems
        return items?.first?.location.coordinate
    }

    private func fetchUpcomingRuns() async -> [Run] {
        // Same Supabase endpoint as RunService — anon key is read-only
        let supabaseURL = "https://fznbkrpgfhfeahkdehps.supabase.co"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ6bmJrcnBnZmhmZWFoa2RlaHBzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NjQwNzksImV4cCI6MjA5MTM0MDA3OX0.0jqRCvcWHAlqSAh0b8xhARjRI-8TepHmTJJU4i2Wy0o"
        let now = ISO8601DateFormatter().string(from: Date())
        let urlStr = "\(supabaseURL)/rest/v1/events?select=*,clubs(*),routes(*)&occurs_at=gte.\(now)&order=occurs_at.asc"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { dec in
                let c = try dec.singleValueContainer()
                let s = try c.decode(String.self)
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: s) { return d }
                iso.formatOptions = [.withInternetDateTime]
                if let d = iso.date(from: s) { return d }
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot decode date: \(s)")
            }
            return try decoder.decode([Run].self, from: data)
        } catch {
            return []
        }
    }
}

// MARK: - App Shortcuts (Siri phrases)
// These phrases are available hands-free without any Shortcuts app setup.

struct FindMyRunShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowNextRunIntent(),
            phrases: [
                "Show my next run in \(.applicationName)",
                "When is my next run in \(.applicationName)",
                "What's my next run in \(.applicationName)"
            ],
            shortTitle: "Next Run",
            systemImageName: "figure.run.circle.fill"
        )
        AppShortcut(
            intent: OpenMyRunsIntent(),
            phrases: [
                "Open my runs in \(.applicationName)",
                "Show saved runs in \(.applicationName)",
                "My runs in \(.applicationName)"
            ],
            shortTitle: "My Runs",
            systemImageName: "bookmark.fill"
        )
        AppShortcut(
            intent: FindRunsIntent(),
            phrases: [
                // Generic triggers — Siri asks for each parameter
                "Find a run in \(.applicationName)",
                "Find runs in \(.applicationName)",
                "Search for runs in \(.applicationName)",
                "Use \(.applicationName) to look for a run",
                "Use \(.applicationName) to find a run",
                // Date pre-filled — e.g. "Find a this weekend run in FindMyRun"
                "Find a \(\.$dateRange) run in \(.applicationName)",
                "Use \(.applicationName) to find a \(\.$dateRange) run",
                "Search for \(\.$dateRange) runs in \(.applicationName)",
            ],
            shortTitle: "Find a Run",
            systemImageName: "magnifyingglass"
        )
    }
}
