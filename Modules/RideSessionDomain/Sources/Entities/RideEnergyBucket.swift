import Foundation

public struct RideEnergyBucket: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let updatedAt: Date
    public let startDistanceKilometers: Double
    public let endDistanceKilometers: Double
    public let stateOfChargePercent: Int?
    public let consumedEnergyWattHours: Double
    public let recoveredEnergyWattHours: Double

    public var distanceKilometers: Double {
        max(endDistanceKilometers - startDistanceKilometers, .zero)
    }

    public var netEnergyWattHours: Double {
        consumedEnergyWattHours - recoveredEnergyWattHours
    }

    public var efficiencyWattHoursPerKilometer: Double? {
        guard distanceKilometers >= Constants.minimumChartDistanceKilometers,
              netEnergyWattHours.isFinite else { return nil }
        return netEnergyWattHours / distanceKilometers
    }

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        updatedAt: Date? = nil,
        startDistanceKilometers: Double,
        endDistanceKilometers: Double? = nil,
        stateOfChargePercent: Int? = nil,
        consumedEnergyWattHours: Double = .zero,
        recoveredEnergyWattHours: Double = .zero
    ) {
        self.id = id
        self.startedAt = startedAt
        self.updatedAt = updatedAt ?? startedAt
        self.startDistanceKilometers = startDistanceKilometers
        self.endDistanceKilometers = endDistanceKilometers ?? startDistanceKilometers
        self.stateOfChargePercent = stateOfChargePercent
        self.consumedEnergyWattHours = consumedEnergyWattHours
        self.recoveredEnergyWattHours = recoveredEnergyWattHours
    }

    func recording(_ sample: RideEnergyBucketSample) -> Self {
        Self(
            id: id,
            startedAt: startedAt,
            updatedAt: max(sample.date, updatedAt),
            startDistanceKilometers: startDistanceKilometers,
            endDistanceKilometers: max(endDistanceKilometers, sample.distanceKilometers),
            stateOfChargePercent: sample.stateOfChargePercent ?? stateOfChargePercent,
            consumedEnergyWattHours: consumedEnergyWattHours + sample.consumedWattHours,
            recoveredEnergyWattHours: recoveredEnergyWattHours + sample.recoveredWattHours
        )
    }

    func shouldRoll(at date: Date, distanceKilometers: Double) -> Bool {
        date.timeIntervalSince(startedAt) >= Constants.maximumDurationSeconds
            || distanceKilometers - startDistanceKilometers >= Constants.maximumDistanceKilometers
    }

    enum Constants {
        static let maximumDurationSeconds: TimeInterval = 30
        static let maximumDistanceKilometers = 0.25
        static let minimumChartDistanceKilometers = 0.01
    }
}

struct RideEnergyBucketSample {
    let date: Date
    let distanceKilometers: Double
    let stateOfChargePercent: Int?
    let consumedWattHours: Double
    let recoveredWattHours: Double
}
