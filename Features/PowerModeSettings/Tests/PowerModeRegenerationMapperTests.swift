import BikeDomain
@testable import PowerModeSettings
import SettingsDomain
import Testing

@MainActor
@Suite("Power mode regeneration presentation")
struct PowerModeRegenerationMapperTests {
    @Test("Keeps negative raw regeneration out of rider controls")
    func rejectsNegativeRegenerationForRiderControl() throws {
        let mapper = PowerModeSettingsMapperFactory.make(locale: .init(identifier: "en_US"))
        let state = mapper.map(.init(
            telemetry: .init(powerModeConfigurations: [
                0: .init(mapIndex: 0, horsepower: 35, regenerativeBrakingPercent: -8)
            ]),
            connection: .init(state: .receivingTelemetry(peripheralName: "FENR Debug")),
            settings: .init(),
            profile: .init(vin: "FENRTEST000000001"),
            selectedMapIndex: 0,
            isRefreshing: false,
            refreshError: nil,
            nameError: nil,
            isBaseControlReady: true
        ))

        let regeneration = try #require(state.adjustments.first { $0.id == .regeneration })
        #expect(regeneration.value == nil)
        #expect(regeneration.valueText == "Unavailable")
        #expect(!regeneration.isEnabled)
        #expect(regeneration.minimum == 0)
    }
}
