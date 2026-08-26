import BikeDomain
import Testing

@Suite("Bike telemetry state")
struct BikeTelemetryTests {
    @Test("Unknown status remains unknown before the first status packet")
    func unknownStatusDoesNotBecomeOff() {
        let telemetry = BikeTelemetry()

        #expect(telemetry.runState == .unknown)
    }

    @Test("A decoded inactive status is off")
    func inactiveStatusIsOff() {
        let telemetry = BikeTelemetry(statusFlags: BikeStatusFlags())

        #expect(telemetry.runState == .off)
    }

    @Test("Battery aliases and focused telemetry share one source of truth")
    func batteryAliasesUseFocusedTelemetryStorage() {
        var telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 70),
            healthLevel: .known(percent: 96)
        )

        #expect(telemetry.batteryTelemetry.stateOfCharge == .known(percent: 70))
        #expect(telemetry.batteryTelemetry.stateOfHealth == .known(percent: 96))

        telemetry.batteryTelemetry.stateOfCharge = .known(percent: 69)
        telemetry.healthLevel = .known(percent: 95)

        #expect(telemetry.batteryLevel == .known(percent: 69))
        #expect(telemetry.batteryTelemetry.stateOfHealth == .known(percent: 95))
    }
}
