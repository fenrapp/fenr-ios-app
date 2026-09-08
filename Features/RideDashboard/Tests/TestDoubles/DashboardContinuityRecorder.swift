@testable import RideDashboard

@MainActor
final class DashboardContinuityRecorder {
    private(set) var phases: [RideDashboardContinuityPhase] = []

    func record(_ phase: RideDashboardContinuityPhase) {
        phases.append(phase)
    }
}
