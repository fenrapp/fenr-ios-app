public struct DashboardIndicatorViewData: Equatable, Identifiable, Sendable {
    public let id: String
    public let symbolName: String
    public let accessibilityLabel: String
    public let accessibilityValue: String
    public let isActive: Bool
    public let emphasis: DashboardIndicatorEmphasis

    public init(
        id: String,
        symbolName: String,
        accessibilityLabel: String,
        accessibilityValue: String,
        isActive: Bool,
        emphasis: DashboardIndicatorEmphasis
    ) {
        self.id = id
        self.symbolName = symbolName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.isActive = isActive
        self.emphasis = emphasis
    }
}
