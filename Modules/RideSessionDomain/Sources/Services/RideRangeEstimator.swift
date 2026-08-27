import Foundation

public struct RideRangeEstimate: Equatable, Sendable {
    public enum Confidence: String, Equatable, Sendable {
        case learning
        case adapting
        case stable
    }

    public let estimatedRangeKilometers: Double?
    public let typicalRangeKilometers: Double?
    public let currentRangeKilometers: Double?
    public let typicalEfficiencyWattHoursPerKilometer: Double?
    public let currentEfficiencyWattHoursPerKilometer: Double?
    public let blendedEfficiencyWattHoursPerKilometer: Double?
    public let remainingEnergyWattHours: Double
    public let recentDistanceKilometers: Double
    public let confidence: Confidence

    public init(
        estimatedRangeKilometers: Double?,
        typicalRangeKilometers: Double?,
        currentRangeKilometers: Double?,
        typicalEfficiencyWattHoursPerKilometer: Double?,
        currentEfficiencyWattHoursPerKilometer: Double?,
        blendedEfficiencyWattHoursPerKilometer: Double?,
        remainingEnergyWattHours: Double,
        recentDistanceKilometers: Double,
        confidence: Confidence
    ) {
        self.estimatedRangeKilometers = estimatedRangeKilometers
        self.typicalRangeKilometers = typicalRangeKilometers
        self.currentRangeKilometers = currentRangeKilometers
        self.typicalEfficiencyWattHoursPerKilometer = typicalEfficiencyWattHoursPerKilometer
        self.currentEfficiencyWattHoursPerKilometer = currentEfficiencyWattHoursPerKilometer
        self.blendedEfficiencyWattHoursPerKilometer = blendedEfficiencyWattHoursPerKilometer
        self.remainingEnergyWattHours = remainingEnergyWattHours
        self.recentDistanceKilometers = recentDistanceKilometers
        self.confidence = confidence
    }
}

public struct RideRangeEstimator: Sendable {
    public init() {}

    public func estimate(
        trip: RideTrip?,
        historicalTrips: [RideTrip],
        stateOfChargePercent: Int?,
        batteryCapacityWattHours: Double,
        recentWindowKilometers: Double = 10
    ) -> RideRangeEstimate {
        let remainingEnergy = remainingEnergyWattHours(
            stateOfChargePercent: stateOfChargePercent,
            batteryCapacityWattHours: batteryCapacityWattHours
        )
        let historicalEfficiencies = historicalTrips.compactMap { historicalTrip -> Double? in
            guard historicalTrip.isEfficiencyEligibleForHistory,
                  let efficiency = historicalTrip.efficiencyWattHoursPerKilometer,
                  efficiency.isFinite,
                  efficiency > .zero else { return nil }
            return efficiency
        }
        let typicalEfficiency = median(historicalEfficiencies)
        let recent = recentEfficiency(
            buckets: trip?.energyBuckets ?? [],
            windowKilometers: recentWindowKilometers
        )
        let currentEfficiency = recent.efficiency
        let blendedEfficiency = blendedEfficiency(
            typical: typicalEfficiency,
            current: currentEfficiency,
            recentDistanceKilometers: recent.distance
        )
        return RideRangeEstimate(
            estimatedRangeKilometers: range(remainingEnergy: remainingEnergy, efficiency: blendedEfficiency),
            typicalRangeKilometers: range(remainingEnergy: remainingEnergy, efficiency: typicalEfficiency),
            currentRangeKilometers: range(remainingEnergy: remainingEnergy, efficiency: currentEfficiency),
            typicalEfficiencyWattHoursPerKilometer: typicalEfficiency,
            currentEfficiencyWattHoursPerKilometer: currentEfficiency,
            blendedEfficiencyWattHoursPerKilometer: blendedEfficiency,
            remainingEnergyWattHours: remainingEnergy,
            recentDistanceKilometers: recent.distance,
            confidence: confidence(
                historicalCount: historicalEfficiencies.count,
                recentDistanceKilometers: recent.distance,
                hasEstimate: blendedEfficiency != nil
            )
        )
    }
}

private extension RideRangeEstimator {
    func remainingEnergyWattHours(
        stateOfChargePercent: Int?,
        batteryCapacityWattHours: Double
    ) -> Double {
        guard let stateOfChargePercent,
              batteryCapacityWattHours.isFinite,
              batteryCapacityWattHours > .zero else { return .zero }
        let stateOfCharge = min(max(Double(stateOfChargePercent), .zero), 100) / 100
        return batteryCapacityWattHours * stateOfCharge
    }

    func recentEfficiency(
        buckets: [RideEnergyBucket],
        windowKilometers: Double
    ) -> (efficiency: Double?, distance: Double) {
        let validWindow = max(windowKilometers, .zero)
        var selected: [RideEnergyBucket] = []
        var distance = 0.0
        for bucket in buckets.reversed() where bucket.distanceKilometers > .zero {
            selected.append(bucket)
            distance += bucket.distanceKilometers
            if distance >= validWindow { break }
        }
        let netEnergy = selected.reduce(.zero) { $0 + $1.netEnergyWattHours }
        guard distance >= Constants.minimumRecentDistanceKilometers,
              netEnergy.isFinite else { return (nil, distance) }
        let efficiency = netEnergy / distance
        return (efficiency > .zero ? efficiency : nil, distance)
    }

    func blendedEfficiency(
        typical: Double?,
        current: Double?,
        recentDistanceKilometers: Double
    ) -> Double? {
        switch (typical, current) {
        case let (.some(typical), .some(current)):
            let currentWeight = min(
                recentDistanceKilometers / Constants.fullAdaptationDistanceKilometers,
                Constants.maximumCurrentWeight
            )
            return typical * (1 - currentWeight) + current * currentWeight
        case let (.some(typical), nil):
            return typical
        case let (nil, .some(current)):
            return current
        case (nil, nil):
            return nil
        }
    }

    func range(remainingEnergy: Double, efficiency: Double?) -> Double? {
        guard remainingEnergy > .zero,
              let efficiency,
              efficiency.isFinite,
              efficiency > .zero else { return nil }
        return remainingEnergy / efficiency
    }

    func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    func confidence(
        historicalCount: Int,
        recentDistanceKilometers: Double,
        hasEstimate: Bool
    ) -> RideRangeEstimate.Confidence {
        guard hasEstimate else { return .learning }
        if historicalCount >= Constants.minimumStableHistoricalTrips,
           recentDistanceKilometers >= Constants.stableRecentDistanceKilometers {
            return .stable
        }
        return .adapting
    }

    enum Constants {
        static let minimumRecentDistanceKilometers = 2.0
        static let fullAdaptationDistanceKilometers = 5.0
        static let maximumCurrentWeight = 0.75
        static let minimumStableHistoricalTrips = 3
        static let stableRecentDistanceKilometers = 5.0
    }
}
