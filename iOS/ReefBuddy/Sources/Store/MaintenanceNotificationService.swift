import Foundation
import UserNotifications

// MARK: - Maintenance Notification Scheduling

final class MaintenanceNotificationService {
    static let shared = MaintenanceNotificationService()

    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Public API (requested surface)

    func scheduleAll(_ schedules: [MaintenanceSchedule]) async {
        print("🗓 [Notifications] scheduleAll — \(schedules.count) schedules")
        for schedule in schedules where !schedule.isDeleted {
            await upsertSchedule(schedule)
        }
    }

    func upsertSchedule(_ schedule: MaintenanceSchedule) async {
        print("🗓 [Notifications] upsertSchedule id=\(schedule.id) enabled=\(schedule.enabled) kind=\(schedule.scheduleKind.rawValue)")
        await deleteSchedule(scheduleId: schedule.id)
        guard schedule.enabled else {
            print("🗓 [Notifications] skipped (disabled)")
            return
        }

        switch schedule.scheduleKind {
        case .weekly:
            await scheduleWeekly(schedule)
        case .intervalDays:
            await rescheduleWindow(schedule)
        }
    }

    func deleteSchedule(scheduleId: UUID) async {
        let prefix = identifierPrefix(scheduleId)
        let pending = await pendingRequests()
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// For interval schedules, schedule the next rolling window (10 occurrences).
    func rescheduleWindow(_ schedule: MaintenanceSchedule) async {
        guard schedule.scheduleKind == .intervalDays else { return }
        guard let interval = schedule.intervalDays, interval >= 1 else { return }

        // Clear any existing window first
        let prefix = identifierPrefix(schedule.id)
        let pending = await pendingRequests()
        let existingIds = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !existingIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: existingIds)
        }

        let occurrences = computeNextIntervalOccurrences(
            intervalDays: interval,
            timeLocal: schedule.timeLocal,
            timezone: schedule.timezone,
            count: 10
        )

        for date in occurrences {
            let id = intervalIdentifier(scheduleId: schedule.id, fireDate: date, timezone: schedule.timezone)
            let content = notificationContent(for: schedule)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendarComponents(for: date, timezone: schedule.timezone),
                repeats: false
            )
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            _ = try? await addRequest(request)
        }
    }

    // MARK: - Authorization

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await getAuthorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    // MARK: - Private scheduling

    private func scheduleWeekly(_ schedule: MaintenanceSchedule) async {
        guard let weekdays = schedule.weekdays, !weekdays.isEmpty else { return }

        let (hour, minute) = parseTimeLocal(schedule.timeLocal) ?? (9, 0)
        for weekday in weekdays.sorted() {
            var comps = DateComponents()
            comps.weekday = isoToCalendarWeekday(weekday) // Calendar: 1=Sun..7=Sat
            comps.hour = hour
            comps.minute = minute

            let id = weeklyIdentifier(scheduleId: schedule.id, isoWeekday: weekday)
            let content = notificationContent(for: schedule)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            _ = try? await addRequest(request)
        }
    }

    private func notificationContent(for schedule: MaintenanceSchedule) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = schedule.type.badgeText
        content.body = notificationBody(for: schedule)
        content.sound = .default
        content.userInfo = [
            "kind": "maintenance",
            "scheduleId": schedule.id.uuidString,
            "tankId": schedule.tankId.uuidString,
            "type": schedule.type.rawValue
        ]
        return content
    }

    private func notificationBody(for schedule: MaintenanceSchedule) -> String {
        switch schedule.type {
        case .waterChange:
            return "Time for a water change. Tap to log it."
        case .filter:
            return "Time to service your filter. Tap for quick actions."
        case .testing:
            return "Time to test your water. Tap to enter results."
        }
    }

    // MARK: - Identifier helpers

    private func identifierPrefix(_ scheduleId: UUID) -> String {
        "maintenance.\(scheduleId.uuidString)."
    }

    private func weeklyIdentifier(scheduleId: UUID, isoWeekday: Int) -> String {
        "\(identifierPrefix(scheduleId))weekly.\(isoWeekday)"
    }

    private func intervalIdentifier(scheduleId: UUID, fireDate: Date, timezone: String) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = TimeZone(identifier: timezone) ?? .current
        fmt.dateFormat = "yyyyMMdd"
        return "\(identifierPrefix(scheduleId))\(fmt.string(from: fireDate))"
    }

    // MARK: - Date helpers

    private func parseTimeLocal(_ value: String) -> (Int, Int)? {
        let parts = value.split(separator: ":").map(String.init)
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return (h, m)
    }

    private func calendarComponents(for date: Date, timezone: String) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timezone) ?? .current
        return cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    private func computeNextIntervalOccurrences(intervalDays: Int, timeLocal: String, timezone: String, count: Int) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timezone) ?? .current

        let now = Date()
        let (hour, minute) = parseTimeLocal(timeLocal) ?? (9, 0)

        var startComponents = cal.dateComponents([.year, .month, .day], from: now)
        startComponents.hour = hour
        startComponents.minute = minute

        var next = cal.date(from: startComponents) ?? now
        if next <= now {
            next = cal.date(byAdding: .day, value: 1, to: next) ?? next
        }

        var results: [Date] = []
        var cursor = next
        while results.count < count {
            results.append(cursor)
            cursor = cal.date(byAdding: .day, value: intervalDays, to: cursor) ?? cursor.addingTimeInterval(TimeInterval(intervalDays * 24 * 3600))
        }
        return results
    }

    private func isoToCalendarWeekday(_ iso: Int) -> Int {
        // ISO: 1=Mon..7=Sun
        // Calendar: 1=Sun..7=Sat
        return iso == 7 ? 1 : (iso + 1)
    }

    // MARK: - Async wrappers

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { cont in
            center.getPendingNotificationRequests { reqs in
                cont.resume(returning: reqs)
            }
        }
    }

    private func addRequest(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: ()) }
            }
        }
    }
}

