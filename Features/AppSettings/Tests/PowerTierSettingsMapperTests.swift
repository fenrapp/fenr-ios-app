import AppSettings
import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain
import Testing

@Suite("Power tier settings presentation")
struct PowerTierSettingsMapperTests {
    private let mapper = AppSettingsViewStateMapper()
    private let syntheticVIN = "FENRTEST000000001"

    @Test("Claimed Alpha stays pending without BLE evidence")
    func claimedAlphaIsPending() {
        let state = map(profile: .init(vin: syntheticVIN, declaredPowerTier: .alpha))

        #expect(state.powerTier.status == "Pending bike verification")
        #expect(state.powerTier.evidence == nil)
    }

    @Test("Declared Standard warns when BLE proves Alpha")
    func mismatchWarns() {
        let state = map(profile: .init(
            vin: syntheticVIN,
            alphaEvidence: [.powerAboveStandard],
            alphaDetectedAt: .now
        ))

        #expect(state.powerTier.status.contains("Tier mismatch"))
        #expect(state.powerTier.evidence?.contains("Power above 60 HP") == true)
    }

    @Test("Verification requires an authenticated session")
    func verificationRequiresAuthentication() {
        let disconnected = map(profile: .init(vin: syntheticVIN))
        let connected = map(
            profile: .init(vin: syntheticVIN),
            connection: .init(state: .receivingTelemetry(peripheralName: syntheticVIN))
        )

        #expect(!disconnected.powerTier.isVerifyEnabled)
        #expect(connected.powerTier.isVerifyEnabled)
    }

    @Test("Verification feedback does not replace detected tier status")
    func verificationFeedbackDoesNotReplaceDetectedTierStatus() {
        let state = mapper.map(
            settings: AppSettings(),
            locationAuthorizationStatus: .notDetermined,
            profile: .init(
                vin: syntheticVIN,
                alphaEvidence: [.powerAboveStandard]
            ),
            verificationMessage: "Bike verification completed"
        )

        #expect(state.powerTier.status == "Tier mismatch: bike reports Alpha evidence")
        #expect(state.powerTier.verificationMessage == "Bike verification completed")
    }

    private func map(
        profile: BikeProfile,
        connection: BikeConnection = .init()
    ) -> AppSettingsViewState {
        mapper.map(
            settings: AppSettings(),
            locationAuthorizationStatus: .notDetermined,
            profile: profile,
            connection: connection
        )
    }
}
