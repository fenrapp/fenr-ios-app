@testable import RideDashboard
import Testing

@Suite("Dashboard compass rotation")
struct DashboardCompassRotationTests {
    @Test("Crosses north using the shortest transition")
    func crossesNorth() {
        #expect(DashboardCompassRotation.nearestEquivalent(to: 1, from: 359) == 361)
        #expect(DashboardCompassRotation.nearestEquivalent(to: 359, from: 1) == -1)
    }

    @Test("Preserves continuous rotations across repeated updates")
    func preservesContinuity() {
        let first = DashboardCompassRotation.nearestEquivalent(to: 5, from: 355)
        let second = DashboardCompassRotation.nearestEquivalent(to: 15, from: first)

        #expect(first == 365)
        #expect(second == 375)
    }
}
