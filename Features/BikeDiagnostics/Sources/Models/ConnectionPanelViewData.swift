public struct ConnectionPanelViewData: Equatable, Sendable {
    public enum Emphasis: Equatable, Sendable {
        case neutral
        case progress
        case success
        case warning
        case critical
    }

    public let status: String
    public let detail: String
    public let rssi: String
    public let configuredVIN: String
    public let peripheralName: String
    public let peripheralIdentifier: String
    public let emphasis: Emphasis

    public init(
        status: String,
        detail: String,
        rssi: String,
        configuredVIN: String = BikeDiagnosticsText.placeholder,
        peripheralName: String = BikeDiagnosticsText.noPeripheral,
        peripheralIdentifier: String = BikeDiagnosticsText.placeholder,
        emphasis: Emphasis = .neutral
    ) {
        self.status = status
        self.detail = detail
        self.rssi = rssi
        self.configuredVIN = configuredVIN
        self.peripheralName = peripheralName
        self.peripheralIdentifier = peripheralIdentifier
        self.emphasis = emphasis
    }
}
