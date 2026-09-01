import BikeDomain
@testable import BikeLockSettings
import SettingsDomain
import Testing

@Suite("Bike Lock settings presentation")
struct BikeLockSettingsViewStateMapperTests {
    private let vin = "FENRTEST000000001"
    private let mapper = BikeLockSettingsViewStateMapper()

    @Test("Maps the current mode and feature-owned protection options")
    func mapsCurrentModeAndProtectionOptions() {
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: .pin), forVIN: vin)

        let state = mapper.map(
            settings: settings,
            vehicleIdentifier: vin,
            capability: .init(vehicleIdentifier: vin, isAvailable: true),
            isCanonicalTelemetryAvailable: true
        )

        #expect(state.isAvailable)
        #expect(state.currentModeTitle == "PIN")
        #expect(state.canChangePIN)
        #expect(state.protectionOptions.map(\.id) == [.pinAndFaceID, .pin, .withoutPIN])
        #expect(state.protectionOptions.map(\.title) == ["PIN + Face ID", "PIN", "No PIN"])
        #expect(state.protectionOptions.first(where: { $0.id == .pin })?.isSelected == true)
    }

    @Test("Requires PIN setup only when adding protection")
    func requiresPINSetupOnlyWhenAddingProtection() {
        let initial = mapper.map(
            settings: AppSettings(),
            vehicleIdentifier: vin,
            capability: .init(vehicleIdentifier: vin, isAvailable: true),
            isCanonicalTelemetryAvailable: true
        )
        #expect(initial.protectionOptions.first(where: { $0.id == .pin })?.requiresPINSetup == true)
        #expect(initial.protectionOptions.first(where: { $0.id == .pinAndFaceID })?.requiresPINSetup == true)
        #expect(initial.protectionOptions.first(where: { $0.id == .withoutPIN })?.requiresPINSetup == false)

        var protectedSettings = AppSettings()
        protectedSettings.setBikeLockSettings(.init(securityMode: .pin), forVIN: vin)
        let protected = mapper.map(
            settings: protectedSettings,
            vehicleIdentifier: vin,
            capability: .init(vehicleIdentifier: vin, isAvailable: true),
            isCanonicalTelemetryAvailable: true
        )
        #expect(protected.protectionOptions.allSatisfy { !$0.requiresPINSetup })
    }
}
