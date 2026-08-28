import BikeDomain
import Foundation
@testable import PowerModeSettings
import SettingsDomain
import Testing

@Suite("Power mode settings presentation")
struct PowerModeSettingsViewStateMapperTests {
    private let mapper = PowerModeSettingsViewStateMapper()
    private let vin = "FENRTEST000000001"

    @Test("Maps five named modes and confirmed configuration")
    func mapsNamedModes() throws {
        var settings = AppSettings()
        try settings.setPowerModeName(try PowerModeName("ECO"), forVIN: vin, mapIndex: 0)
        let telemetry = BikeTelemetry(
            mode: .index(1),
            powerModeConfigurations: [
                0: .init(
                    mapIndex: 0,
                    horsepower: 35,
                    regenerativeBrakingPercent: 40,
                    powerTractionPercent: 12,
                    brakingTractionPercent: 30
                )
            ]
        )

        let state = mapper.map(.init(
            telemetry: telemetry,
            connection: .init(state: .receivingTelemetry(peripheralName: vin)),
            settings: settings,
            profile: .init(vin: vin),
            selectedMapIndex: 0,
            isRefreshing: false,
            refreshError: nil,
            nameError: nil
        ))

        #expect(state.maps.count == 5)
        #expect(state.maps.map(\.title) == ["ECO", "2", "3", "4", "5"])
        #expect(state.currentName == "ECO")
        #expect(state.adjustments.map(\.valueText) == ["35", "40", "12", "30"])
        #expect(state.adjustments.allSatisfy { !$0.isEnabled })
        #expect(state.statusText == "Bike write verification required")
    }

    @Test("Uses declared tier only as a pending visual range")
    func mapsDeclaredAlphaFallback() {
        let state = mapper.map(.init(
            telemetry: .init(),
            connection: .init(),
            settings: .init(),
            profile: .init(vin: vin, declaredPowerTier: .alpha),
            selectedMapIndex: 0,
            isRefreshing: false,
            refreshError: nil,
            nameError: nil
        ))

        #expect(state.capabilityText == "Alpha expected · verification pending")
        #expect(state.adjustments.first?.maximum == 80)
        #expect(state.adjustments.first?.isEnabled == false)
    }

    @Test("Enables base and traction controls only after their own verification")
    func enablesVerifiedControls() {
        let state = mapper.map(.init(
            telemetry: .init(powerModeConfigurations: [
                0: .init(
                    mapIndex: 0,
                    horsepower: 60,
                    regenerativeBrakingPercent: 50,
                    powerTractionPercent: 20,
                    brakingTractionPercent: 10
                )
            ]),
            connection: .init(state: .receivingTelemetry(peripheralName: "FENR Debug")),
            settings: .init(),
            profile: .init(vin: vin),
            selectedMapIndex: 0,
            isRefreshing: false,
            refreshError: nil,
            nameError: nil,
            isBaseControlReady: true,
            isTractionControlReady: true
        ))

        #expect(state.adjustments.map(\.isEnabled) == [true, true, true, true])
        #expect(state.statusText == "All map controls ready")
    }

}
