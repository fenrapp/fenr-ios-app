public enum AppSettingsUpdateError: Error, Equatable, Sendable {
    case vehicleUnavailable
    case invalidVIN
    case vehicleChanged
    case unreadableStore
    case persistenceFailed
    case invalidChange
    case duplicatePowerModeName
}
