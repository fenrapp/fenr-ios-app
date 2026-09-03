import Foundation

public struct BatteryHealthOverviewViewData: Equatable, Sendable {
    public let status: BatteryHealthOverallStatus
    public let statusDetail: String
    public let stateOfHealthProgress: Double?
    public let stateOfHealthMetric: BatteryHealthMetricViewData?
    public let summaryMetrics: [BatteryHealthMetricViewData]
    public let banners: [BatteryHealthBannerViewData]

    public init(
        status: BatteryHealthOverallStatus = .unavailable,
        statusDetail: String? = nil,
        stateOfHealthProgress: Double? = nil,
        stateOfHealthMetric: BatteryHealthMetricViewData? = nil,
        summaryMetrics: [BatteryHealthMetricViewData] = [],
        banners: [BatteryHealthBannerViewData] = []
    ) {
        self.status = status
        self.statusDetail = statusDetail
            ?? String(localized: .batteryHealthOverviewDefaultDetail)
        self.stateOfHealthProgress = stateOfHealthProgress
        self.stateOfHealthMetric = stateOfHealthMetric
        self.summaryMetrics = summaryMetrics
        self.banners = banners
    }
}
