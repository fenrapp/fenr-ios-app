import Foundation
import MaintenanceLog

struct DemoMaintenanceReminderScheduler: MaintenanceReminderScheduling {
    let scheduler: any MaintenanceReminderScheduling
    let title: String

    func schedule(_ request: MaintenanceDateReminderRequest, requestingAuthorization: Bool) async {
        await scheduler.schedule(
            .init(id: request.id, date: request.date, title: title + ": " + request.title, body: request.body),
            requestingAuthorization: requestingAuthorization
        )
    }

    func cancel(id: UUID) async { await scheduler.cancel(id: id) }
}
