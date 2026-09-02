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
    public let peripheral: String
    public let emphasis: Emphasis

    public init(
        status: String,
        detail: String,
        rssi: String,
        peripheral: String,
        emphasis: Emphasis = .neutral
    ) {
        self.status = status
        self.detail = detail
        self.rssi = rssi
        self.peripheral = peripheral
        self.emphasis = emphasis
    }
}
