public struct BikeDiagnosticsSectionViewData: Equatable, Identifiable, Sendable {
    public enum Style: Equatable, Sendable {
        case metrics
        case powerModes
        case powerTier
    }

    public let id: String
    public let title: String
    public let metrics: [BikeDiagnosticsMetricViewData]
    public let style: Style

    public init(
        id: String,
        title: String,
        metrics: [BikeDiagnosticsMetricViewData],
        style: Style = .metrics
    ) {
        self.id = id
        self.title = title
        self.metrics = metrics
        self.style = style
    }
}
