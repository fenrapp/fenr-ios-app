import SettingsDomain

public enum BikeLockSettingsDestination: Equatable, Sendable {
    case verifyCurrentPIN
    case chooseProtection
    case createPIN(BikeLockSecurityMode)
    case changePIN
}
