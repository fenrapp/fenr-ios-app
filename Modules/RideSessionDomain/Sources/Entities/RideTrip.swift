import Foundation

public struct RideTrip: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let vehicleIdentity: RideVehicleIdentity
    public let applicationSessionID: UUID
    public let startedAt: Date
    public let updatedAt: Date
    public let endedAt: Date?
    public let startingOdometerKilometers: Double?
    public let distanceKilometers: Double
    public let elapsedSeconds: TimeInterval
    public let averageSpeedKilometersPerHour: Double
    public let maximumSpeedKilometersPerHour: Double
    public let accumulatedSpeedKilometersPerHourSeconds: Double
    public let speedSampleDurationSeconds: TimeInterval
    public let lastSpeedKilometersPerHour: Double?
    public let pausedAt: Date?
    public let accumulatedPausedSeconds: TimeInterval
    public let isAwaitingOdometerRebase: Bool
    public let consumedEnergyWattHours: Double
    public let recoveredEnergyWattHours: Double
    public let electricalObservedSeconds: TimeInterval
    public let electricalExpectedSeconds: TimeInterval
    public let maximumDischargePowerWatts: Double
    public let maximumRegenerationPowerWatts: Double
    public let lastElectricalPowerWatts: Double?
    public let lastElectricalSampleAt: Date?
    public let isAwaitingElectricalRebase: Bool
    public let energyBuckets: [RideEnergyBucket]

    public var isPaused: Bool { pausedAt != nil }
    public var confirmedVIN: String? { vehicleIdentity.confirmedVIN }
    public var netEnergyWattHours: Double { consumedEnergyWattHours - recoveredEnergyWattHours }
    public var electricalCoverage: Double {
        guard electricalObservedSeconds.isFinite,
              electricalExpectedSeconds.isFinite,
              electricalObservedSeconds >= .zero,
              electricalExpectedSeconds > .zero else { return .zero }
        return min(max(electricalObservedSeconds / electricalExpectedSeconds, .zero), 1)
    }
    public var efficiencyWattHoursPerKilometer: Double? {
        guard distanceKilometers.isFinite,
              distanceKilometers >= Constants.minimumEfficiencyDistanceKilometers,
              netEnergyWattHours.isFinite else { return nil }
        return netEnergyWattHours / distanceKilometers
    }
    public var hasSufficientElectricalCoverage: Bool {
        electricalCoverage >= Constants.minimumHistoricalElectricalCoverage
    }
    public var isEfficiencyEligibleForHistory: Bool {
        confirmedVIN != nil
            && hasSufficientElectricalCoverage
            && efficiencyWattHoursPerKilometer != nil
    }

    public init(
        id: UUID = UUID(),
        vehicleIdentity: RideVehicleIdentity,
        applicationSessionID: UUID,
        startedAt: Date,
        updatedAt: Date? = nil,
        endedAt: Date? = nil,
        startingOdometerKilometers: Double? = nil,
        distanceKilometers: Double = .zero,
        elapsedSeconds: TimeInterval = .zero,
        averageSpeedKilometersPerHour: Double = .zero,
        maximumSpeedKilometersPerHour: Double = .zero,
        accumulatedSpeedKilometersPerHourSeconds: Double = .zero,
        speedSampleDurationSeconds: TimeInterval = .zero,
        lastSpeedKilometersPerHour: Double? = nil,
        pausedAt: Date? = nil,
        accumulatedPausedSeconds: TimeInterval = .zero,
        isAwaitingOdometerRebase: Bool = false,
        consumedEnergyWattHours: Double = .zero,
        recoveredEnergyWattHours: Double = .zero,
        electricalObservedSeconds: TimeInterval = .zero,
        electricalExpectedSeconds: TimeInterval = .zero,
        maximumDischargePowerWatts: Double = .zero,
        maximumRegenerationPowerWatts: Double = .zero,
        lastElectricalPowerWatts: Double? = nil,
        lastElectricalSampleAt: Date? = nil,
        isAwaitingElectricalRebase: Bool = true,
        energyBuckets: [RideEnergyBucket] = []
    ) {
        self.id = id
        self.vehicleIdentity = vehicleIdentity
        self.applicationSessionID = applicationSessionID
        self.startedAt = startedAt
        self.updatedAt = updatedAt ?? startedAt
        self.endedAt = endedAt
        self.startingOdometerKilometers = startingOdometerKilometers
        self.distanceKilometers = distanceKilometers
        self.elapsedSeconds = elapsedSeconds
        self.averageSpeedKilometersPerHour = averageSpeedKilometersPerHour
        self.maximumSpeedKilometersPerHour = maximumSpeedKilometersPerHour
        self.accumulatedSpeedKilometersPerHourSeconds = accumulatedSpeedKilometersPerHourSeconds
        self.speedSampleDurationSeconds = speedSampleDurationSeconds
        self.lastSpeedKilometersPerHour = lastSpeedKilometersPerHour
        self.pausedAt = pausedAt
        self.accumulatedPausedSeconds = accumulatedPausedSeconds
        self.isAwaitingOdometerRebase = isAwaitingOdometerRebase
        self.consumedEnergyWattHours = consumedEnergyWattHours
        self.recoveredEnergyWattHours = recoveredEnergyWattHours
        self.electricalObservedSeconds = electricalObservedSeconds
        self.electricalExpectedSeconds = electricalExpectedSeconds
        self.maximumDischargePowerWatts = maximumDischargePowerWatts
        self.maximumRegenerationPowerWatts = maximumRegenerationPowerWatts
        self.lastElectricalPowerWatts = lastElectricalPowerWatts
        self.lastElectricalSampleAt = lastElectricalSampleAt
        self.isAwaitingElectricalRebase = isAwaitingElectricalRebase
        self.energyBuckets = energyBuckets
    }

    public func updating(
        at date: Date,
        odometerKilometers: Double?,
        speedKilometersPerHour: Double?
    ) -> Self {
        guard endedAt == nil, !isPaused else { return self }
        let effectiveDate = max(date, startedAt)
        let currentOdometer = validOdometer(odometerKilometers)
        let rebasedOdometer = rebasedStartingOdometer(from: currentOdometer)
        let startingOdometer = rebasedOdometer
            ?? startingOdometerKilometers
            ?? currentOdometer
        let observedDistance = distance(from: startingOdometer, to: currentOdometer)
        let updatedDistance = isAwaitingOdometerRebase
            ? distanceKilometers
            : max(distanceKilometers, observedDistance ?? .zero)
        let activeElapsed = effectiveDate.timeIntervalSince(startedAt) - accumulatedPausedSeconds
        let updatedElapsed = max(elapsedSeconds, activeElapsed)
        let speed = validSpeed(speedKilometersPerHour)
        let updatedMaximumSpeed = max(maximumSpeedKilometersPerHour, speed ?? .zero)
        let sampleDuration = max(effectiveDate.timeIntervalSince(updatedAt), .zero)
        let previousSpeed = validSpeed(lastSpeedKilometersPerHour)
        let previousSampleDuration = effectiveSpeedSampleDuration
        let updatedSampleDuration = previousSampleDuration + (previousSpeed == nil ? .zero : sampleDuration)
        let updatedSpeedIntegral = effectiveSpeedIntegral + (previousSpeed ?? .zero) * sampleDuration
        let averageSpeed = updatedSampleDuration > .zero
            ? updatedSpeedIntegral / updatedSampleDuration
            : averageSpeedKilometersPerHour

        return copy(
            updatedAt: effectiveDate,
            startingOdometerKilometers: .some(startingOdometer),
            distanceKilometers: updatedDistance,
            elapsedSeconds: updatedElapsed,
            averageSpeedKilometersPerHour: averageSpeed,
            maximumSpeedKilometersPerHour: updatedMaximumSpeed,
            accumulatedSpeedKilometersPerHourSeconds: updatedSpeedIntegral,
            speedSampleDurationSeconds: updatedSampleDuration,
            lastSpeedKilometersPerHour: .some(speed),
            isAwaitingOdometerRebase: isAwaitingOdometerRebase && rebasedOdometer == nil,
            electricalExpectedSeconds: updatedElapsed
        )
    }

    public func paused(at date: Date) -> Self {
        guard endedAt == nil, !isPaused else { return self }
        let updated = updating(at: date, odometerKilometers: nil, speedKilometersPerHour: nil)
        return updated.copy(
            pausedAt: .some(updated.updatedAt),
            lastElectricalPowerWatts: .some(nil),
            lastElectricalSampleAt: .some(nil),
            isAwaitingElectricalRebase: true
        )
    }

    public func resumed(
        at date: Date,
        odometerKilometers: Double?,
        speedKilometersPerHour: Double?
    ) -> Self {
        guard endedAt == nil, let pausedAt else { return self }
        let effectiveDate = max(date, pausedAt)
        let updatedPausedSeconds = accumulatedPausedSeconds + effectiveDate.timeIntervalSince(pausedAt)
        let currentOdometer = validOdometer(odometerKilometers)
        let rebasedOdometer = currentOdometer.flatMap { odometer in
            let candidate = odometer - distanceKilometers
            return candidate >= .zero ? candidate : nil
        }
        return copy(
            updatedAt: effectiveDate,
            startingOdometerKilometers: .some(rebasedOdometer ?? startingOdometerKilometers),
            lastSpeedKilometersPerHour: .some(validSpeed(speedKilometersPerHour)),
            pausedAt: .some(nil),
            accumulatedPausedSeconds: updatedPausedSeconds,
            isAwaitingOdometerRebase: rebasedOdometer == nil,
            lastElectricalPowerWatts: .some(nil),
            lastElectricalSampleAt: .some(nil),
            isAwaitingElectricalRebase: true
        )
    }

    public func completed(at date: Date) -> Self {
        let completionDate = max(date, updatedAt)
        let updated = isPaused
            ? self
            : updating(at: completionDate, odometerKilometers: nil, speedKilometersPerHour: nil)
        return updated.copy(
            updatedAt: completionDate,
            endedAt: .some(completionDate),
            pausedAt: .some(nil),
            lastElectricalPowerWatts: .some(nil),
            lastElectricalSampleAt: .some(nil),
            isAwaitingElectricalRebase: true
        )
    }

    public func promotingVehicleIdentity(to vin: String) -> Self {
        copy(vehicleIdentity: .vin(vin))
    }

}
