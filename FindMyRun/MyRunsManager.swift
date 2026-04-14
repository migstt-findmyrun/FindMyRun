//
//  MyRunsManager.swift
//  FindMyRun
//

import Foundation

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
    }
}
