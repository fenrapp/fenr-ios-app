import Foundation
import MaintenanceLog
import TestSupport

actor MaintenanceReminderRecorder: MaintenanceReminderScheduling {
    struct Scheduled: Equatable {
        let request: MaintenanceDateReminderRequest
        let requestedAuthorization: Bool
    }

    private(set) var scheduled: [Scheduled] = []
    private(set) var cancelled: [UUID] = []
    private let schedulingGate: TestEventHub<Void>
    private var blocksScheduling = false

    init(schedulingGate: TestEventHub<Void>) {
        self.schedulingGate = schedulingGate
    }

    func suspendScheduling() {
        blocksScheduling = true
    }

    func schedule(_ request: MaintenanceDateReminderRequest, requestingAuthorization: Bool) async {
        scheduled.append(.init(request: request, requestedAuthorization: requestingAuthorization))
        if blocksScheduling {
            for await _ in await schedulingGate.stream() { break }
        }
    }

    func cancel(id: UUID) async {
        cancelled.append(id)
    }
}
