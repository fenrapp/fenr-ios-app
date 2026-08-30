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
        #expect(store.lines == ["5001 type=Backpack raw=3 maximumPower=1000 W maxSoc=100%"])
        for index in 0 ..< 50 {
            store.append("line \(index)")
        }

        #expect(store.lines.count == 40)
        #expect(store.lines.last == "line 49")
    }

    @Test("Logs presentation names alongside exact raw charger identifiers", arguments: [
        (BikeChargerType.standard, "Standard raw=0"),
        (BikeChargerType.fast, "Fast raw=2"),
        (BikeChargerType.backpack, "Backpack raw=3"),
        (BikeChargerType.unknown(91), "Unknown (91) raw=91")
    ])
    func chargerTypeLog(charger: BikeChargerType, expectedType: String) {
        var store = ChargeControlLogStore()
        let charging = ChargeControlFixtures.chargingHealth(chargerType: charger).chargingStatus

        if let charging {
            store.appendTelemetry(charging: charging)
        }

        #expect(store.lines.first?.contains("type=\(expectedType) ") == true)
    }
}
