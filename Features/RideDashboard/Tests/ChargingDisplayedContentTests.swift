@testable import RideDashboard
import Testing

struct ChargingDisplayedContentTests {
    @Test("Charging display comparison ignores only unused numeric precision",
          arguments: ChargingDisplayedContentFixtures.Change.allCases)
    func comparesEveryPresentedProperty(change: ChargingDisplayedContentFixtures.Change) {
        let original = ChargingDisplayedContentFixtures.state()
        let changed = ChargingDisplayedContentFixtures.state(change)
        #expect(original.hasSameDisplayedContent(as: changed) == (change == .none || change == .invisibleValue))
        #expect(changed.hasSameDisplayedContent(as: original) == (change == .none || change == .invisibleValue))
        if change == .invisibleValue {
            #expect(original != changed)
            #expect(original.batteryTemperature != changed.batteryTemperature)
        }
    }
}
