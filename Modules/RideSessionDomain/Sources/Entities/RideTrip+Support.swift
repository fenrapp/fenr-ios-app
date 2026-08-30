import Foundation

extension RideTrip {
    func validOdometer(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= .zero else { return nil }
        return value
    }

    func validSpeed(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= .zero else { return nil }
        return value
    }

    func distance(from start: Double?, to current: Double?) -> Double? {
        guard let start, let current, current >= start else { return nil }
        return current - start
    }

    func rebasedStartingOdometer(from current: Double?) -> Double? {
        guard isAwaitingOdometerRebase, let current else { return nil }
        let candidate = current - distanceKilometers
        return candidate >= .zero ? candidate : nil
    }

    var effectiveSpeedSampleDuration: TimeInterval {
        guard speedSampleDurationSeconds == .zero,
              averageSpeedKilometersPerHour > .zero,
              elapsedSeconds > .zero else { return speedSampleDurationSeconds }
        return elapsedSeconds
    }

    var effectiveSpeedIntegral: Double {
        guard accumulatedSpeedKilometersPerHourSeconds == .zero,
              speedSampleDurationSeconds == .zero,
              averageSpeedKilometersPerHour > .zero,
              elapsedSeconds > .zero else { return accumulatedSpeedKilometersPerHourSeconds }
        return averageSpeedKilometersPerHour * elapsedSeconds
    }

    func copy(
        vehicleIdentity: RideVehicleIdentity? = nil,
        updatedAt: Date? = nil,
        endedAt: Date?? = nil,
        startingOdometerKilometers: Double?? = nil,
        distanceKilometers: Double? = nil,
        elapsedSeconds: TimeInterval? = nil,
        averageSpeedKilometersPerHour: Double? = nil,
        maximumSpeedKilometersPerHour: Double? = nil,
        accumulatedSpeedKilometersPerHourSeconds: Double? = nil,
        speedSampleDurationSeconds: TimeInterval? = nil,
        lastSpeedKilometersPerHour: Double?? = nil,
        pausedAt: Date?? = nil,
        accumulatedPausedSeconds: TimeInterval? = nil,
        isAwaitingOdometerRebase: Bool? = nil,
        consumedEnergyWattHours: Double? = nil,
        recoveredEnergyWattHours: Double? = nil,
        electricalObservedSeconds: TimeInterval? = nil,
        electricalExpectedSeconds: TimeInterval? = nil,
        maximumDischargePowerWatts: Double? = nil,
        maximumRegenerationPowerWatts: Double? = nil,
        lastElectricalPowerWatts: Double?? = nil,
        lastElectricalSampleAt: Date?? = nil,
        isAwaitingElectricalRebase: Bool? = nil,
        maximumLeftLeanDegrees: Double? = nil,
        maximumRightLeanDegrees: Double? = nil,
        maximumUphillPitchDegrees: Double? = nil,
        maximumDownhillPitchDegrees: Double? = nil,
        attitudeSource: RideAttitudeSource? = nil,
        energyBuckets: [RideEnergyBucket]? = nil
    ) -> Self {
        Self(
            id: id,
            vehicleIdentity: vehicleIdentity ?? self.vehicleIdentity,
            applicationSessionID: applicationSessionID,
            startedAt: startedAt,
            updatedAt: updatedAt ?? self.updatedAt,
            endedAt: endedAt ?? self.endedAt,
            startingOdometerKilometers: startingOdometerKilometers ?? self.startingOdometerKilometers,
            distanceKilometers: distanceKilometers ?? self.distanceKilometers,
            elapsedSeconds: elapsedSeconds ?? self.elapsedSeconds,
            averageSpeedKilometersPerHour: averageSpeedKilometersPerHour ?? self.averageSpeedKilometersPerHour,
            maximumSpeedKilometersPerHour: maximumSpeedKilometersPerHour ?? self.maximumSpeedKilometersPerHour,
            accumulatedSpeedKilometersPerHourSeconds: accumulatedSpeedKilometersPerHourSeconds
                ?? self.accumulatedSpeedKilometersPerHourSeconds,
            speedSampleDurationSeconds: speedSampleDurationSeconds ?? self.speedSampleDurationSeconds,
            lastSpeedKilometersPerHour: lastSpeedKilometersPerHour ?? self.lastSpeedKilometersPerHour,
            pausedAt: pausedAt ?? self.pausedAt,
            accumulatedPausedSeconds: accumulatedPausedSeconds ?? self.accumulatedPausedSeconds,
            isAwaitingOdometerRebase: isAwaitingOdometerRebase ?? self.isAwaitingOdometerRebase,
            consumedEnergyWattHours: consumedEnergyWattHours ?? self.consumedEnergyWattHours,
            recoveredEnergyWattHours: recoveredEnergyWattHours ?? self.recoveredEnergyWattHours,
            electricalObservedSeconds: electricalObservedSeconds ?? self.electricalObservedSeconds,
            electricalExpectedSeconds: electricalExpectedSeconds ?? self.electricalExpectedSeconds,
            maximumDischargePowerWatts: maximumDischargePowerWatts ?? self.maximumDischargePowerWatts,
            maximumRegenerationPowerWatts: maximumRegenerationPowerWatts
                ?? self.maximumRegenerationPowerWatts,
            lastElectricalPowerWatts: lastElectricalPowerWatts ?? self.lastElectricalPowerWatts,
            lastElectricalSampleAt: lastElectricalSampleAt ?? self.lastElectricalSampleAt,
            isAwaitingElectricalRebase: isAwaitingElectricalRebase ?? self.isAwaitingElectricalRebase,
            maximumLeftLeanDegrees: maximumLeftLeanDegrees ?? self.maximumLeftLeanDegrees,
            maximumRightLeanDegrees: maximumRightLeanDegrees ?? self.maximumRightLeanDegrees,
            maximumUphillPitchDegrees: maximumUphillPitchDegrees ?? self.maximumUphillPitchDegrees,
            maximumDownhillPitchDegrees: maximumDownhillPitchDegrees ?? self.maximumDownhillPitchDegrees,
            attitudeSource: attitudeSource ?? self.attitudeSource,
            energyBuckets: energyBuckets ?? self.energyBuckets
        )
    }

    enum Constants {
        static let minimumEfficiencyDistanceKilometers = 1.0
        static let minimumHistoricalElectricalCoverage = 0.9
    }
}
