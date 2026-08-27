import Foundation

public struct DashboardRangeViewData: Equatable, Sendable {
    public struct ConsumptionPoint: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let distance: Double
        public let efficiency: Double

        public init(id: UUID, distance: Double, efficiency: Double) {
            self.id = id
            self.distance = distance
            self.efficiency = efficiency
        }
    }

    public struct BatteryPoint: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let distance: Double
        public let percentage: Double

        public init(id: UUID, distance: Double, percentage: Double) {
            self.id = id
            self.distance = distance
            self.percentage = percentage
        }
    }

    public enum Status: String, Equatable, Sendable {
        case learning = "LEARNING"
        case adapting = "ADAPTING"
        case stable = "STABLE"
    }

    public let rangeText: String
    public let distanceUnitText: String
    public let status: Status
    public let typicalRangeText: String
    public let currentRangeText: String
    public let batteryText: String
    public let remainingEnergyText: String
    public let typicalEfficiency: Double?
    public let consumptionPoints: [ConsumptionPoint]
    public let batteryPoints: [BatteryPoint]
    public let peakDischargeText: String
    public let peakRegenerationText: String
    public let isLoadingHistory: Bool

    public init(
        rangeText: String = "—",
        distanceUnitText: String = "km",
        status: Status = .learning,
        typicalRangeText: String = "—",
        currentRangeText: String = "—",
        batteryText: String = "—",
        remainingEnergyText: String = "—",
        typicalEfficiency: Double? = nil,
        consumptionPoints: [ConsumptionPoint] = [],
        batteryPoints: [BatteryPoint] = [],
        peakDischargeText: String = "—",
        peakRegenerationText: String = "—",
        isLoadingHistory: Bool = false
    ) {
        self.rangeText = rangeText
        self.distanceUnitText = distanceUnitText
        self.status = status
        self.typicalRangeText = typicalRangeText
        self.currentRangeText = currentRangeText
        self.batteryText = batteryText
        self.remainingEnergyText = remainingEnergyText
        self.typicalEfficiency = typicalEfficiency
        self.consumptionPoints = consumptionPoints
        self.batteryPoints = batteryPoints
        self.peakDischargeText = peakDischargeText
        self.peakRegenerationText = peakRegenerationText
        self.isLoadingHistory = isLoadingHistory
    }
}
