public struct RideNavigationArrivalPrompt: Equatable, Sendable {
    public let title: String
    public let detail: String

    public init(
        title: String = "You reached the end. Finish route?",
        detail: String = "You can finish this ride or keep following the route."
    ) {
        self.title = title
        self.detail = detail
    }
}
