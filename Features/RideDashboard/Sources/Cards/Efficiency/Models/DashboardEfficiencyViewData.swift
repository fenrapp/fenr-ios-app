import Foundation

public struct DashboardEfficiencyViewData: Equatable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case calculated = "CALCULATED"
        case partial = "PARTIAL"
        case calculating = "CALCULATING"
        case netRecovery = "NET RECOVERY"
    }

    public struct PowerPoint: Equatable, Identifiable, Sendable {
        public let id: Date
        public let date: Date
        public let kilowatts: Double

        public init(date: Date, kilowatts: Double) {
            id = date
            self.date = date
            self.kilowatts = kilowatts
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
