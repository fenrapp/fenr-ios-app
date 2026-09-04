public enum BikeDiagnosticsNavigationEvent: Equatable, Sendable {
    case show(BikeDiagnosticsDestination)
    case openBatteryHealth
}
