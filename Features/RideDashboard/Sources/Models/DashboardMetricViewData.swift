public struct DashboardMetricViewData: Equatable, Sendable {
    public let valueText: String
    public let unitText: String?
    public let animationValue: Double?

    public init(
        valueText: String = "--",
        unitText: String? = nil,
        animationValue: Double? = nil
    ) {
        self.valueText = valueText
        self.unitText = unitText
        self.animationValue = animationValue
    }
}
