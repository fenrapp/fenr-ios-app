public struct PowerModeNavigationViewState: Equatable, Sendable {
    public let detail: String

    public init(detail: String = "No custom names") {
        self.detail = detail
    }
}
