import BikeDomain
@testable import RideDashboard
import Testing

struct DashboardAdvancedCurveIndicatorTests {
    @Test func onlyRidingMapShowsTheIcon() {
        let states: [BikeRunState] = [.unknown, .off, .neutral, .charging, .crawlForward, .crawlReverse]
        for state in states {
            #expect(!DashboardGearMapper.map(
                runState: state, modeIndex: 1, modeName: nil, hasAdvancedCurve: true
            ).showsAdvancedCurve)
        }
        #expect(DashboardGearMapper.map(
            runState: .on, modeIndex: 1, modeName: "Enduro", hasAdvancedCurve: true
        ).showsAdvancedCurve)
        #expect(!DashboardGearMapper.map(
            runState: .on, modeIndex: 2, modeName: nil, hasAdvancedCurve: false
        ).showsAdvancedCurve)
        #expect(!DashboardGearMapper.map(
            runState: .on, modeIndex: nil, modeName: nil, hasAdvancedCurve: true
        ).showsAdvancedCurve)
    }
}
