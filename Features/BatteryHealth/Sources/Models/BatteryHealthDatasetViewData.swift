public struct BatteryHealthDatasetViewData: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: BatteryHealthStatusViewData

    public init(id: String, title: String, status: BatteryHealthStatusViewData) {
        self.id = id
        self.title = title
        self.status = status
    }
}
