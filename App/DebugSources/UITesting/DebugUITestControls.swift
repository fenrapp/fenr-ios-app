import Observation

@MainActor
@Observable
final class DebugUITestControls {
    private(set) var historyReadFailure = false
    private(set) var maintenanceReadFailure = false

    func setHistoryReadFailure(_ enabled: Bool) { historyReadFailure = enabled }
    func setMaintenanceReadFailure(_ enabled: Bool) { maintenanceReadFailure = enabled }
}
