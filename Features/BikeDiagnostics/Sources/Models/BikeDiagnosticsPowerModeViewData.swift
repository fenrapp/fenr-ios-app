public struct BikeDiagnosticsPowerModeViewData: Equatable, Identifiable, Sendable {
    public struct Metric: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let value: String

        public init(id: String, title: String, value: String) {
            self.id = id
            self.title = title
            self.value = value
        }
    }

    public let id: Int
    public let title: String
    public let isActive: Bool
    public let metrics: [Metric]

    public init(id: Int, title: String, isActive: Bool, metrics: [Metric]) {
        self.id = id
        self.title = title
        self.isActive = isActive
        self.metrics = metrics
    }
}
