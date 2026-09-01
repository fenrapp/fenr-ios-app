public struct RideNavigationTrailEntryPrompt: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let availableDirections: [RideNavigationTrailDirection]

    public init(
        title: String,
        detail: String,
        availableDirections: [RideNavigationTrailDirection]
    ) {
        self.title = title
        self.detail = detail
        self.availableDirections = availableDirections
    }
}
