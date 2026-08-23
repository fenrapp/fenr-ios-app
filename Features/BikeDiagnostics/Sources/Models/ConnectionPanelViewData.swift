public struct ConnectionPanelViewData: Equatable, Sendable {
    public let status: String
    public let detail: String
    public let rssi: String
    public let peripheral: String

    public init(status: String, detail: String, rssi: String, peripheral: String) {
        self.status = status
        self.detail = detail
        self.rssi = rssi
        self.peripheral = peripheral
    }
}
