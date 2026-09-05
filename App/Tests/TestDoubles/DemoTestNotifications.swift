import MaintenanceLog

@MainActor
final class DemoTestNotifications: DemoNotificationManaging {
    private(set) var cancelledPrefixes: [String] = []

    func makeScheduler(prefix: String) -> any MaintenanceReminderScheduling {
        NoOpMaintenanceReminderScheduler()
    }

    func cancelAll(prefix: String) async {
        cancelledPrefixes.append(prefix)
    }
}
