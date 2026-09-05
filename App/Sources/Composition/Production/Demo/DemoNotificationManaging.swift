import Foundation
import MaintenanceLog
import UserNotifications

@MainActor
protocol DemoNotificationManaging: Sendable {
    func makeScheduler(prefix: String) -> any MaintenanceReminderScheduling
    func cancelAll(prefix: String) async
}

struct SystemDemoNotifications: DemoNotificationManaging {
    let center: UNUserNotificationCenter
    let calendar: Calendar

    func makeScheduler(prefix: String) -> any MaintenanceReminderScheduling {
        SystemMaintenanceReminderScheduler(center: center, calendar: calendar, identifierPrefix: prefix)
    }

    func cancelAll(prefix: String) async {
        let requests = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
        )
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) }
        )
    }
}
