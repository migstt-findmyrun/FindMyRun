//
//  MyRunsManager.swift
//  FindMyRun
//

import Foundation
import WidgetKit

@Observable
final class MyRunsManager {
    private static let key = "savedRuns"

    var notifications: NotificationManager?

    private(set) var savedRuns: [Run] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([Run].self, from: data) {
            savedRuns = decoded
        } else {
            savedRuns = []
        }
        // Sync any pre-existing saved runs into the App Group so the widget sees them.
        syncToWidget()
    }

    func isSaved(_ runId: String) -> Bool {
        savedRuns.contains { $0.id == runId }
    }

    func toggle(_ run: Run) {
        if let index = savedRuns.firstIndex(where: { $0.id == run.id }) {
            savedRuns.remove(at: index)
            notifications?.cancel(runId: run.id)
        } else {
            savedRuns.append(run)
            notifications?.schedule(for: run)
        }
    }

    func remove(_ runId: String) {
        savedRuns.removeAll { $0.id == runId }
        notifications?.cancel(runId: runId)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(savedRuns) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
        syncToWidget()
    }

    private func syncToWidget() {
        SharedRunStore.save(savedRuns.map {
            WidgetRun(
                id: $0.id,
                title: $0.title,
                clubName: $0.clubs.name,
                clubCity: $0.clubs.city,
                occursAt: $0.occursAt,
                address: $0.address,
                distanceKm: $0.routes?.distanceKm,
                polyline: $0.routes?.summaryPolyline ?? $0.routes?.polyline
            )
        })
        WidgetCenter.shared.reloadAllTimelines()
    }
}
