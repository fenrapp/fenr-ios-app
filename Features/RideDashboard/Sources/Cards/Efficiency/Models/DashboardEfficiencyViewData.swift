import Foundation

public struct DashboardEfficiencyViewData: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case calculated
        case partial
        case calculating
        case netRecovery

        var text: String {
            switch self {
            case .calculated: rideDashboardLocalized(.rideDashboardEfficiencyStatusCalculated)
            case .partial: rideDashboardLocalized(.rideDashboardEfficiencyStatusPartial)
            case .calculating: rideDashboardLocalized(.rideDashboardEfficiencyStatusCalculating)
            case .netRecovery: rideDashboardLocalized(.rideDashboardEfficiencyStatusNetRecovery)
            }
        }
    }

    public struct PowerPoint: Equatable, Identifiable, Sendable {
        public let id: Date
        public let date: Date
        public let usedKilowatts: Double
        public let regenKilowatts: Double

        public init(
            date: Date,
            usedKilowatts: Double,
            regenKilowatts: Double
        ) {
            id = date
            self.date = date
            self.usedKilowatts = usedKilowatts
            self.regenKilowatts = regenKilowatts
        }
    }

    public struct TrendPoint: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let date: Date
        public let efficiency: Double

        public init(id: UUID, date: Date, efficiency: Double) {
            self.id = id
            self.date = date
            self.efficiency = efficiency
        }
    }

    public let valueText: String
    public let unitText: String
    public let status: Status
    public let usedEnergyText: String
    public let recoveredEnergyText: String
    public let powerPoints: [PowerPoint]
    public let trendPoints: [TrendPoint]
    public let trendIsLoading: Bool
    public let hasConfirmedVehicle: Bool

    public init(
        valueText: String = "—",
        unitText: String = "Wh/km",
        status: Status = .calculating,
        usedEnergyText: String = "0 Wh",
        recoveredEnergyText: String = "0 Wh",
        powerPoints: [PowerPoint] = [],
        trendPoints: [TrendPoint] = [],
        trendIsLoading: Bool = false,
        hasConfirmedVehicle: Bool = false
    ) {
        self.valueText = valueText
        self.unitText = unitText
        self.status = status
        self.usedEnergyText = usedEnergyText
        self.recoveredEnergyText = recoveredEnergyText
        self.powerPoints = powerPoints
        self.trendPoints = trendPoints
        self.trendIsLoading = trendIsLoading
        self.hasConfirmedVehicle = hasConfirmedVehicle
    }
}
