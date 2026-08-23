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
}
