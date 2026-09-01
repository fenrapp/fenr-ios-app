public struct DashboardConnectionNoticeViewData: Equatable, Sendable {
    public let text: String
    public let accessibilityLabel: String

    public init(
        text: String = "Reconnecting",
        accessibilityLabel: String = "Reconnecting to bike"
    ) {
        self.text = text
        self.accessibilityLabel = accessibilityLabel
    }
}
