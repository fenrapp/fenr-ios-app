public struct BatteryHealthDatasetViewData: Equatable, Identifiable, Sendable {
    public enum State: Equatable, Sendable {
        case awaiting
        case capturedOnly
        case decoded
    }

    public let id: String
    public let title: String
    public let status: BatteryHealthStatusViewData
    public let state: State
    public let timestamp: String?
    public let byteCount: Int?
    public let hex: String?

    public init(
        id: String,
        title: String,
        status: BatteryHealthStatusViewData,
        state: State = .awaiting,
        timestamp: String? = nil,
        byteCount: Int? = nil,
        hex: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.state = state
        self.timestamp = timestamp
        self.byteCount = byteCount
        self.hex = hex
    }
}
