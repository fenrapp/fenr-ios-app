public struct DashboardConnectionNoticeViewData: Equatable, Sendable {
    public let text: String
    public let accessibilityLabel: String

    public init(
        text: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.text = text ?? rideDashboardLocalized(.rideDashboardConnectionReconnecting)
        self.accessibilityLabel = accessibilityLabel
            ?? rideDashboardLocalized(.rideDashboardConnectionReconnectingAccessibility)
    }
}
