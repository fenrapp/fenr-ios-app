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

    @Test("Run state follows crawl, charging, gear, on, and off priority", arguments: [
        (
            BikeStatusFlags(isOn: true, isCharging: true, isInGear: true, crawlState: .forward),
            BikeRunState.crawlForward
        ),
        (
            BikeStatusFlags(isOn: true, isCharging: true, isInGear: true, crawlState: .reverse),
            BikeRunState.crawlReverse
        ),
        (BikeStatusFlags(isOn: true, isCharging: true, isInGear: true), BikeRunState.charging),
        (BikeStatusFlags(isOn: true, isInGear: true), BikeRunState.on),
        (BikeStatusFlags(isOn: true), BikeRunState.neutral),
        (BikeStatusFlags(), BikeRunState.off)
    ])
    func runStatePriority(flags: BikeStatusFlags, expected: BikeRunState) {
        #expect(BikeTelemetry(statusFlags: flags).runState == expected)
    }

    @Test("Active power mode uses the validated zero-based configuration index")
    func activePowerModeConfiguration() {
        let active = BikePowerModeConfiguration(mapIndex: 4, horsepower: 80)
        let telemetry = BikeTelemetry(
            mode: .index(5),
            powerModeConfigurations: [0: .init(mapIndex: 0, horsepower: 48), 4: active]
        )

        #expect(telemetry.activePowerModeConfiguration == active)
        #expect(BikeTelemetry(mode: .index(0), powerModeConfigurations: [0: active])
            .activePowerModeConfiguration == nil)
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
