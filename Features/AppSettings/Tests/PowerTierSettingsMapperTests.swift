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

        #expect(String(localized: state.powerTier.status) == "Pending bike verification")
        #expect(String(localized: state.powerTier.navigationDetail) == "Alpha · Unverified")
        #expect(state.powerTier.evidence == nil)
    }

    @Test("Declared Standard warns when BLE proves Alpha")
    func mismatchWarns() {
        let state = map(profile: .init(
            vin: syntheticVIN,
            alphaEvidence: [.powerAboveStandard],
            alphaDetectedAt: .now
        ))

        #expect(String(localized: state.powerTier.status) == "Tier mismatch: bike reports Alpha evidence")
        #expect(String(localized: state.powerTier.navigationDetail) == "Model mismatch")
        #expect(state.powerTier.evidence.map(String.init(localized:))?.contains("Power above 60 HP") == true)
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

        #expect(String(localized: state.powerTier.status) == "Tier mismatch: bike reports Alpha evidence")
        #expect(state.powerTier.verificationMessage.map(String.init(localized:)) == "Bike verification completed")
        #expect(!state.powerTier.verificationMessageIsError)
    }

    @Test("Verification failure is surfaced as an error")
    func verificationFailureIsError() {
        let state = mapper.map(
            settings: AppSettings(),
            locationAuthorizationStatus: .notDetermined,
            profile: .init(vin: syntheticVIN),
            verificationMessage: "Verification failed",
            verificationMessageIsError: true
        )

        #expect(state.powerTier.verificationMessage.map(String.init(localized:)) == "Verification failed")
        #expect(state.powerTier.verificationMessageIsError)
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
