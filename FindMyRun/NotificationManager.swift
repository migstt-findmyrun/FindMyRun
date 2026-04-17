//
//  NotificationManager.swift
//  FindMyRun
//

import Foundation
import UserNotifications

@Observable
final class NotificationManager {
    private static let enabledKey  = "runNotificationsEnabled"
    private static let advanceKey  = "runNotificationAdvanceHours"

    static let advanceOptions: [Int] = [1, 2, 4, 6, 12, 24, 48]

    var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Self.enabledKey)
            if !notificationsEnabled { cancelAllRunNotifications() }
        }
    }

    var advanceHours: Int {
        didSet {
            UserDefaults.standard.set(advanceHours, forKey: Self.advanceKey)
        }
    }

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        let stored = UserDefaults.standard.integer(forKey: Self.advanceKey)
        advanceHours = stored > 0 ? stored : 24
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            await refreshStatus()
            return granted
        } catch {
            return false
        }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { authorizationStatus = settings.authorizationStatus }
    }

    func schedule(for run: Run) {
        guard notificationsEnabled else { return }
        let triggerDate = run.occursAt.addingTimeInterval(-Double(advanceHours) * 3600)
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = advanceHours >= 24 ? "Run tomorrow!" : "Run in \(advanceHours)h!"
        content.body = "\(run.title) · \(run.clubs.name) at \(timeString(run.occursAt))"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationId(run.id), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel(runId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationId(runId)])
    }

    func scheduleAll(runs: [Run]) {
        runs.forEach { schedule(for: $0) }
    }

    func cancelAllRunNotifications() {
        Task {
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let ids = pending.map(\.identifier).filter { $0.hasPrefix("run-reminder-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func notificationId(_ runId: String) -> String { "run-reminder-\(runId)" }

    private func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
