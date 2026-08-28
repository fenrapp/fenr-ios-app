public struct PowerModeMapViewData: Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let accessibilityLabel: String
    public let isSelected: Bool

    public init(
        id: Int,
        title: String,
        accessibilityLabel: String,
        isSelected: Bool
    ) {
        self.id = id
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.isSelected = isSelected
    }
}
