import BikeDomain
import Foundation
@testable import PowerModeSettings
import SettingsDomain
import Testing

@Suite("Power mode control feedback presentation")
struct PowerModeSettingsControlFeedbackMapperTests {
    private let mapper = PowerModeSettingsViewStateMapper(locale: Locale(identifier: "en_US"))
    private let vin = "FENRTEST000000001"

    @Test("Maps applying, confirmed, and failed feedback to only the affected control")
    func mapsPerControlFeedback() {
        let applying = mapper.map(input(
            isApplyingControl: true,
            activeAdjustmentID: .regeneration
        ))
        #expect(applying.adjustments.map(\.feedback.state) == [
            .idle,
            .applying,
            .idle,
            .idle
        ])
        #expect(applying.adjustments[1].feedback.isActivity)

        let confirmed = mapper.map(input(
            recentAdjustmentResult: .confirmed(.powerTraction)
        ))
        #expect(confirmed.adjustments.map(\.feedback.state) == [
            .idle,
            .idle,
            .confirmed,
            .idle
        ])
        #expect(confirmed.adjustments[2].feedback.emphasis == .positive)

        let failed = mapper.map(input(
            recentAdjustmentResult: .failed(.brakingTraction, message: "Unable to apply")
        ))
        #expect(failed.adjustments.map(\.feedback.state) == [
            .idle,
            .idle,
            .idle,
            .failed
        ])
        #expect(failed.adjustments[3].feedback.title == "Unable to apply")
        #expect(failed.adjustments[3].feedback.emphasis == .critical)
    }

    private func input(
        isApplyingControl: Bool = false,
        activeAdjustmentID: PowerModeAdjustmentID? = nil,
        recentAdjustmentResult: PowerModeAdjustmentResult? = nil
    ) -> PowerModeSettingsMappingInput {
        .init(
            telemetry: .init(powerModeConfigurations: [
                0: .init(
                    mapIndex: 0,
                    horsepower: 35,
                    regenerativeBrakingPercent: 40,
                    powerTractionPercent: 20,
                    brakingTractionPercent: 15
                )
            ]),
            connection: .init(state: .receivingTelemetry(peripheralName: "FENR Debug")),
            settings: .init(),
            profile: .init(vin: vin),
            selectedMapIndex: 0,
            isRefreshing: false,
            refreshError: nil,
            nameError: nil,
            isApplyingControl: isApplyingControl,
            activeAdjustmentID: activeAdjustmentID,
            recentAdjustmentResult: recentAdjustmentResult,
            isBaseControlReady: true,
            isTractionControlReady: true,
            isCanonicalTelemetryAvailable: true
        )
    }
}
