import Foundation

public struct RideHistoryDetailViewState: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case idle
        case loading
        case unavailable
        case loaded
    }

    public struct Metric: Equatable, Identifiable, Sendable {
        public let id: String
        public let symbolName: String
        public let label: String
        public let value: String
        public let detail: String?

        public init(
            id: String,
            symbolName: String,
            label: String,
            value: String,
            detail: String? = nil
        ) {
            self.id = id
            self.symbolName = symbolName
            self.label = label
            self.value = value
            self.detail = detail
        }
    }

    public struct Comparison: Equatable, Identifiable, Sendable {
        public enum Emphasis: Equatable, Sendable {
            case neutral
            case positive
            case negative
        }

        public let id: String
        public let label: String
        public let value: String
        public let detail: String
        public let emphasis: Emphasis

        public init(
            id: String,
            label: String,
            value: String,
            detail: String,
            emphasis: Emphasis
        ) {
            self.id = id
            self.label = label
            self.value = value
            self.detail = detail
            self.emphasis = emphasis
        }
    }

    public struct ChartPoint: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let distance: Double
        public let value: Double

        public init(id: UUID, distance: Double, value: Double) {
            self.id = id
            self.distance = distance
            self.value = value
        }
    }

    public let status: Status
    public let rideID: UUID?
    public let title: String
    public let subtitle: String
    public let distanceText: String
    public let overviewMetrics: [Metric]
    public let energyMetrics: [Metric]
    public let performanceMetrics: [Metric]
    public let dynamicsMetrics: [Metric]
    public let comparisons: [Comparison]
    public let comparisonDetail: String?
    public let batteryPoints: [ChartPoint]
    public let efficiencyPoints: [ChartPoint]
    public let distanceUnit: String
    public let efficiencyUnit: String

    public init(
        status: Status = .idle,
        rideID: UUID? = nil,
        title: String? = nil,
        subtitle: String = "",
        distanceText: String = "",
        overviewMetrics: [Metric] = [],
        energyMetrics: [Metric] = [],
        performanceMetrics: [Metric] = [],
        dynamicsMetrics: [Metric] = [],
        comparisons: [Comparison] = [],
        comparisonDetail: String? = nil,
        batteryPoints: [ChartPoint] = [],
        efficiencyPoints: [ChartPoint] = [],
        distanceUnit: String = "km",
        efficiencyUnit: String = "Wh/km"
    ) {
        self.status = status
        self.rideID = rideID
        self.title = title ?? String(localized: .rideHistoryRideDetails)
        self.subtitle = subtitle
        self.distanceText = distanceText
        self.overviewMetrics = overviewMetrics
        self.energyMetrics = energyMetrics
        self.performanceMetrics = performanceMetrics
        self.dynamicsMetrics = dynamicsMetrics
        self.comparisons = comparisons
        self.comparisonDetail = comparisonDetail
        self.batteryPoints = batteryPoints
        self.efficiencyPoints = efficiencyPoints
        self.distanceUnit = distanceUnit
        self.efficiencyUnit = efficiencyUnit
    }
}
