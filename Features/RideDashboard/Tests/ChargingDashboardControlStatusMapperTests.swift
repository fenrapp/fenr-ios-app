import ChargeControl
import RideDashboard
import Testing

@Suite("Charging dashboard control status mapper")
struct ChargingDashboardControlStatusMapperTests {
    private let mapper = ChargingDashboardControlStatusMapper()

    @Test("Distinguishes charging power updates")
    func mapsChargingPowerUpdateFeedback() {
        let status = mapper.map(ChargeControlState(
            selectedWatts: 1_700,
            confirmedWatts: 1_500,
            selectedTargetPercent: 80,
            confirmedTargetPercent: 80,
            phase: .updating
        ))

        #expect(status == .init(
            text: "UPDATING CHARGING POWER",
            systemImage: "bolt.fill",
            emphasis: .power,
            showsActivityIndicator: true
        ))
    }

    @Test("Distinguishes charge limit updates")
    func mapsChargeLimitUpdateFeedback() {
        let status = mapper.map(ChargeControlState(
            selectedWatts: 1_500,
            confirmedWatts: 1_500,
            selectedTargetPercent: 78,
            confirmedTargetPercent: 80,
            phase: .updating
        ))

        #expect(status == .init(
            text: "UPDATING CHARGE LIMIT",
            systemImage: "battery.100percent",
            emphasis: .target,
            showsActivityIndicator: true
        ))
    }
}
