import Foundation
import UserNotifications

public struct MaintenanceDateReminderRequest: Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let title: String
    public let body: String

    public init(id: UUID, date: Date, title: String, body: String) {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
    }
}

public protocol MaintenanceReminderScheduling: Sendable {
    func schedule(_ request: MaintenanceDateReminderRequest, requestingAuthorization: Bool) async
    func cancel(id: UUID) async
}

public actor NoOpMaintenanceReminderScheduler: MaintenanceReminderScheduling {
    public init() {}
    public func schedule(_: MaintenanceDateReminderRequest, requestingAuthorization _: Bool) async {}
    public func cancel(id _: UUID) async {}
}

public final class SystemMaintenanceReminderScheduler: MaintenanceReminderScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let identifierPrefix: String

    public init(
        center: UNUserNotificationCenter, calendar: Calendar, identifierPrefix: String = "maintenance."
    ) {
        self.center = center
        self.calendar = calendar
        self.identifierPrefix = identifierPrefix
    }

    public func schedule(
        _ request: MaintenanceDateReminderRequest,
        requestingAuthorization: Bool
    ) async {
        if requestingAuthorization {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request.date)
        let notification = UNNotificationRequest(
            identifier: identifier(for: request.id),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(notification)
    }

    public func cancel(id: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: id)])
    }

    private func identifier(for id: UUID) -> String {
        "\(identifierPrefix)\(id.uuidString)"
    }
}
