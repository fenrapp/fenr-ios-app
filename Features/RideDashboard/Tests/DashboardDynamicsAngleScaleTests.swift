@testable import RideDashboard
import Testing

@Suite("Dashboard dynamics angle scale")
struct DashboardDynamicsAngleScaleTests {
    @Test("Clamps values to the instrument range")
    func clampsToRange() {
        let scale = DashboardDynamicsAngleScale(maximumAngleDegrees: 60)

        #expect(scale.clamped(-80) == -60)
        #expect(scale.clamped(24) == 24)
        #expect(scale.clamped(90) == 60)
    }

    @Test("Activates ticks only between zero and the current direction")
    func activatesDirectionalTicks() {
        let scale = DashboardDynamicsAngleScale(maximumAngleDegrees: 45)

        #expect(scale.isActiveTick(10, for: 18, tolerance: 1))
        #expect(!scale.isActiveTick(-10, for: 18, tolerance: 1))
        #expect(scale.isActiveTick(-10, for: -18, tolerance: 1))
        #expect(!scale.isActiveTick(10, for: -18, tolerance: 1))
    }
}
