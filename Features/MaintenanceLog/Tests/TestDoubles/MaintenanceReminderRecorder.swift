import Foundation
import MaintenanceLog

actor MaintenanceReminderRecorder: MaintenanceReminderScheduling {
    struct Scheduled: Equatable {
        let request: MaintenanceDateReminderRequest
        let requestedAuthorization: Bool
    }

    private(set) var scheduled: [Scheduled] = []
    private(set) var cancelled: [UUID] = []

    func schedule(_ request: MaintenanceDateReminderRequest, requestingAuthorization: Bool) async {
        scheduled.append(.init(request: request, requestedAuthorization: requestingAuthorization))
    }

    func cancel(id: UUID) async {
        cancelled.append(id)
    }
}
