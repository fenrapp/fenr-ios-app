import BikeDomain
@testable import ChargeControl
import Testing

@Suite("Charge control logs")
struct ChargeControlLogStoreTests {
    @Test("Telemetry duplicates are suppressed and the log remains bounded")
    func telemetryLogIsDeduplicatedAndBounded() {
        var store = ChargeControlLogStore()
        let charging = ChargeControlFixtures.chargingHealth().chargingStatus

        if let charging {
            store.appendTelemetry(charging: charging)
            store.appendTelemetry(charging: charging)
        }
        for index in 0 ..< 50 {
            store.append("line \(index)")
        }

        #expect(store.lines.count == 40)
        #expect(store.lines.last == "line 49")
    }
}
