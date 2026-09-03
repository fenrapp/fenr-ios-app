import BikeDomain
import Foundation
@testable import PowerModeSettings
import SettingsDomain
import Testing

@Suite("Power mode settings presentation")
struct PowerModeSettingsViewStateMapperTests {
    private let mapper = PowerModeSettingsViewStateMapper(locale: Locale(identifier: "en_US"))
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
        #expect(state.controlGroups.map(\.id) == [.performance, .traction])
        #expect(state.controlGroups.map(\.adjustments.count) == [2, 2])
        #expect(state.controlGroups[0].adjustments.map(\.id) == [.power, .regeneration])
        #expect(state.controlGroups[1].adjustments.map(\.id) == [
            .powerTraction,
            .brakingTraction
        ])
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
            isTractionControlReady: true,
            isCanonicalTelemetryAvailable: true
        ))

        #expect(state.adjustments.map(\.isEnabled) == [true, true, true, true])
        #expect(state.statusText == "All map controls ready")
        #expect(state.status.title == "Bike connected")
        #expect(state.status.systemImage == "checkmark.circle.fill")
        #expect(state.status.emphasis == .positive)
        #expect(!state.status.isActivity)
    }

    @Test("Maps typed adjustment IDs, supported ranges, and injected locale")
    func mapsTypedAdjustmentIDsRangesAndLocale() {
        let localizedMapper = PowerModeSettingsViewStateMapper(
            locale: Locale(identifier: "es_ES")
        )
        let state = localizedMapper.map(.init(
            telemetry: .init(powerModeConfigurations: [
                0: .init(
                    mapIndex: 0,
                    horsepower: 35,
                    regenerativeBrakingPercent: 42.5,
                    powerTractionPercent: 12,
                    brakingTractionPercent: 30
                )
            ]),
            connection: .init(state: .receivingTelemetry(peripheralName: "FENR Debug")),
            settings: .init(),
            profile: .init(vin: vin, declaredPowerTier: .alpha),
            selectedMapIndex: 0,
            isRefreshing: false,
            refreshError: nil,
            nameError: nil
        ))

        #expect(state.adjustments.map(\.id) == PowerModeAdjustmentID.allCases)
        #expect(state.adjustments.map(\.minimum) == [10, 0, 0, 0])
        #expect(state.adjustments.map(\.maximum) == [80, 100, 100, 100])
        #expect(state.adjustments.map(\.valueText) == ["35", "42,5", "12", "30"])
        #expect(state.adjustments.allSatisfy { $0.localeIdentifier == "es_ES" })
    }

    @Test("Does not enable traction controls for unsupported configuration")
    func doesNotEnableTractionControlsForUnsupportedConfiguration() {
        let unsupportedConfigurations: [(power: Double, braking: Double)] = [
            (-1, 10),
            (10, 101),
            (.nan, 10),
            (10, 12.5)
        ]

        for configuration in unsupportedConfigurations {
            let state = mapper.map(.init(
                telemetry: .init(powerModeConfigurations: [
                    0: .init(
                        mapIndex: 0,
                        horsepower: 35,
                        regenerativeBrakingPercent: 40,
                        powerTractionPercent: configuration.power,
                        brakingTractionPercent: configuration.braking
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
                isTractionControlReady: true,
                isCanonicalTelemetryAvailable: true
            ))

            #expect(state.adjustments.map(\.isEnabled) == [true, true, false, false])
            #expect(state.statusText == "Power and regeneration controls ready")
        }
    }

    @Test("Prioritizes refresh and control statuses")
    func prioritizesRefreshAndControlStatuses() {
        let refreshing = mapper.map(statusInput(
            isRefreshing: true,
            refreshError: "refresh failed",
            controlError: "control failed",
            isApplyingControl: true,
            isPreparingControl: true
        ))
        #expect(refreshing.statusText == "Reading power modes")
        #expect(!refreshing.statusIsError)
        #expect(refreshing.status.isActivity)
        #expect(refreshing.status.systemImage == "arrow.clockwise")

        let refreshFailure = mapper.map(statusInput(
            refreshError: "refresh failed",
            controlError: "control failed",
            isApplyingControl: true,
            isPreparingControl: true
        ))
        #expect(refreshFailure.statusText == "refresh failed")
        #expect(refreshFailure.statusIsError)
        #expect(refreshFailure.status.emphasis == .critical)

        let controlFailure = mapper.map(statusInput(
            controlError: "control failed",
            isApplyingControl: true,
            isPreparingControl: true
        ))
        #expect(controlFailure.statusText == "control failed")
        #expect(controlFailure.statusIsError)

        let applying = mapper.map(statusInput(
            isApplyingControl: true,
            isPreparingControl: true
        ))
        #expect(applying.statusText == "Applying and verifying map")
        #expect(!applying.status.isActivity)

        let preparing = mapper.map(statusInput(isPreparingControl: true))
        #expect(preparing.statusText == "Verifying map write safety")
        #expect(!preparing.status.isActivity)
    }

    @Test("Connection failures do not expose transport messages")
    func connectionFailuresUseSafePresentationCopy() {
        let failed = mapper.map(.init(
            telemetry: .init(),
            connection: .init(state: .failed(message: "private transport detail")),
            settings: .init(),
            profile: .init(vin: vin),
            selectedMapIndex: 0,
            isRefreshing: false,
            refreshError: nil,
            nameError: nil
        ))
        let disconnected = mapper.map(.init(
            telemetry: .init(),
            connection: .init(state: .disconnected(reason: "private disconnect detail")),
            settings: .init(),
            profile: .init(vin: vin),
            selectedMapIndex: 0,
            isRefreshing: false,
            refreshError: nil,
            nameError: nil
        ))

        #expect(failed.connectionText == "Bike connection failed")
        #expect(disconnected.connectionText == "Bike disconnected")
    }

    private func statusInput(
        isRefreshing: Bool = false,
        refreshError: String? = nil,
        controlError: String? = nil,
        isApplyingControl: Bool = false,
        isPreparingControl: Bool = false,
        activeAdjustmentID: PowerModeAdjustmentID? = nil,
        recentAdjustmentResult: PowerModeAdjustmentResult? = nil
    ) -> PowerModeSettingsMappingInput {
        .init(
            telemetry: .init(powerModeConfigurations: [
                0: .init(mapIndex: 0, horsepower: 35, regenerativeBrakingPercent: 40)
            ]),
            connection: .init(state: .receivingTelemetry(peripheralName: "FENR Debug")),
            settings: .init(),
            profile: .init(vin: vin),
            selectedMapIndex: 0,
            isRefreshing: isRefreshing,
            refreshError: refreshError,
            nameError: nil,
            isPreparingControl: isPreparingControl,
            isApplyingControl: isApplyingControl,
            activeAdjustmentID: activeAdjustmentID,
            recentAdjustmentResult: recentAdjustmentResult,
            controlError: controlError,
            isCanonicalTelemetryAvailable: true
        )
    }

}
