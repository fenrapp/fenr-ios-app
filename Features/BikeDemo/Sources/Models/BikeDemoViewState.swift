public struct BikeDemoViewState: Equatable, Sendable {
    public let scenarios: [Scenario]
    public let selectedID: String

    public struct Scenario: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let detail: String
        public let icon: String
    }
}
