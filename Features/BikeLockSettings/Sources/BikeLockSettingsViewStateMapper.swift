import BikeDomain
import Foundation
import SettingsDomain

public struct BikeLockSettingsViewStateMapper: Sendable {
    public init() {}

    public func map(
        settings: AppSettings,
        vehicleIdentifier: String?,
        capability: BikeLockCapabilityState,
        isWorking: Bool = false,
        errorMessage: String? = nil,
        destination: BikeLockSettingsDestination? = nil,
        isCanonicalTelemetryAvailable: Bool = false
    ) -> BikeLockSettingsViewState {
        let currentMode = settings.bikeLockSettings(forVIN: vehicleIdentifier).securityMode
        let isAvailable = vehicleIdentifier != nil
            && capability.isAvailable
            && capability.vehicleIdentifier == vehicleIdentifier
            && isCanonicalTelemetryAvailable
        return .init(
            isAvailable: isAvailable,
            currentModeTitle: title(for: currentMode),
            canChangePIN: currentMode.requiresPIN,
            protectionOptions: options(currentMode: currentMode),
            isWorking: isWorking,
            errorMessage: errorMessage,
            destination: isAvailable ? destination : nil
        )
    }

    public func securityMode(for optionID: BikeLockProtectionOptionID) -> BikeLockSecurityMode {
        switch optionID {
        case .pinAndFaceID: .pinAndFaceID
        case .pin: .pin
        case .withoutPIN: .withoutPIN
        }
    }

    private func options(currentMode: BikeLockSecurityMode) -> [BikeLockProtectionOptionViewData] {
        BikeLockProtectionOptionID.allCases.map { optionID in
            let mode = securityMode(for: optionID)
            return .init(
                id: optionID,
                title: title(for: mode),
                detail: detail(for: mode),
                isSelected: mode == currentMode,
                requiresPINSetup: mode.requiresPIN && !currentMode.requiresPIN
            )
        }
    }

    private func title(for mode: BikeLockSecurityMode) -> String {
        switch mode {
        case .notConfigured: String(localized: .bikeLockSettingsModeNotConfigured)
        case .withoutPIN: String(localized: .bikeLockSettingsModeWithoutPIN)
        case .pin: String(localized: .bikeLockSettingsModePIN)
        case .pinAndFaceID: String(localized: .bikeLockSettingsModePINAndFaceID)
        }
    }

    private func detail(for mode: BikeLockSecurityMode) -> String {
        switch mode {
        case .pinAndFaceID: String(localized: .bikeLockSettingsModePINAndFaceIDDetail)
        case .pin: String(localized: .bikeLockSettingsModePINDetail)
        case .withoutPIN: String(localized: .bikeLockSettingsModeWithoutPINDetail)
        case .notConfigured: ""
        }
    }
}
