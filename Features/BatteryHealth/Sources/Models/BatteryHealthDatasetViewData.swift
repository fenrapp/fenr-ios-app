public struct BatteryHealthDatasetViewData: Equatable, Identifiable, Sendable {
    public enum Status: Equatable, Sendable {
        case awaitingSample
        case captured(String)
        case validated(String)
        case failed(String)
    }

    public let id: String
    public let title: String
    public let status: Status

    public init(id: String, title: String, status: Status) {
        self.id = id
        self.title = title
        self.status = status
    }
}
