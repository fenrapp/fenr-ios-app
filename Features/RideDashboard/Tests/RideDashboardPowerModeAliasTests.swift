import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing

@Suite("Ride dashboard power mode aliases")
struct RideDashboardPowerModeAliasTests {
    @Test("Displays the local alias for an active power mode")
    func mapsPowerModeAlias() throws {
        var settings = AppSettings()
        try settings.setPowerModeName(
            try PowerModeName("Enduro"),
            forVIN: "FENRTEST000000001",
            mapIndex: 2
        )
        let telemetry = BikeTelemetry(
            mode: .index(3),
            speed: .known(kmh: 1, kmhX10: 10),
            statusFlags: BikeStatusFlags(isOn: true, isInGear: true)
        )

        let state = RideDashboardMapperFactory.makeRideMapper(locale: .init(identifier: "en_GB")).map(
            telemetry: telemetry,
            connection: .init(state: .receivingTelemetry(peripheralName: "Synthetic bike")),
            speedKilometersPerHour: 1,
            measurementSystem: .metric,
            powerModeNames: settings.powerModeNames(forVIN: "FENRTEST000000001")
        )

        #expect(state.gear == .init(
            display: .text("Enduro"),
            isActive: true,
            accessibilityLabel: "Power mode Enduro"
        ))
    }
}
