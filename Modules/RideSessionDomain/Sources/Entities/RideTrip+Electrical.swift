import Foundation

public extension RideTrip {
    func updatingElectrical(
        at date: Date,
        powerWatts: Double,
        stateOfChargePercent: Int? = nil,
        maximumSampleGap: TimeInterval = 5
    ) -> Self {
        guard endedAt == nil, !isPaused, powerWatts.isFinite else { return self }
        let maximumDischarge = max(maximumDischargePowerWatts, max(powerWatts, .zero))
        let maximumRegeneration = max(maximumRegenerationPowerWatts, max(-powerWatts, .zero))
        guard !isAwaitingElectricalRebase,
              let previousPower = lastElectricalPowerWatts,
              let previousDate = lastElectricalSampleAt else {
            return copy(
                maximumDischargePowerWatts: maximumDischarge,
                maximumRegenerationPowerWatts: maximumRegeneration,
                lastElectricalPowerWatts: .some(powerWatts),
                lastElectricalSampleAt: .some(date),
                isAwaitingElectricalRebase: false,
                energyBuckets: bucketsStartingIfNeeded(
                    at: date,
                    stateOfChargePercent: stateOfChargePercent
                )
            )
        }

        let duration = date.timeIntervalSince(previousDate)
        guard duration > .zero else { return self }
        guard duration <= maximumSampleGap else {
            return copy(
                maximumDischargePowerWatts: maximumDischarge,
                maximumRegenerationPowerWatts: maximumRegeneration,
                lastElectricalPowerWatts: .some(powerWatts),
                lastElectricalSampleAt: .some(date),
                energyBuckets: appendingEnergyBucket(
                    at: date,
                    stateOfChargePercent: stateOfChargePercent
                )
            )
        }

        let energy = Self.integratedEnergy(from: previousPower, to: powerWatts, duration: duration)
        let recording = EnergyBucketRecording(
            date: date,
            stateOfChargePercent: stateOfChargePercent,
            energy: energy
        )
        return copy(
            consumedEnergyWattHours: consumedEnergyWattHours + energy.consumedWattHours,
            recoveredEnergyWattHours: recoveredEnergyWattHours + energy.recoveredWattHours,
            electricalObservedSeconds: electricalObservedSeconds + duration,
            maximumDischargePowerWatts: maximumDischarge,
            maximumRegenerationPowerWatts: maximumRegeneration,
            lastElectricalPowerWatts: .some(powerWatts),
            lastElectricalSampleAt: .some(date),
            energyBuckets: recordingEnergyBucket(recording)
        )
    }

    func rebasingElectrical() -> Self {
        copy(
            lastElectricalPowerWatts: .some(nil),
            lastElectricalSampleAt: .some(nil),
            isAwaitingElectricalRebase: true
        )
    }

    func restoringEnergyBuckets(_ buckets: [RideEnergyBucket]) -> Self {
        copy(energyBuckets: buckets.sorted { $0.startedAt < $1.startedAt })
    }
}

private extension RideTrip {
    struct IntegratedEnergy {
        let consumedWattHours: Double
        let recoveredWattHours: Double
    }

    struct EnergyBucketRecording {
        let date: Date
        let stateOfChargePercent: Int?
        let energy: IntegratedEnergy
    }

    static func integratedEnergy(from start: Double, to end: Double, duration: TimeInterval) -> IntegratedEnergy {
        if start >= .zero, end >= .zero {
            return .init(
                consumedWattHours: (start + end) * 0.5 * duration / 3_600,
                recoveredWattHours: .zero
            )
        }
        if start <= .zero, end <= .zero {
            return .init(
                consumedWattHours: .zero,
                recoveredWattHours: -(start + end) * 0.5 * duration / 3_600
            )
        }
        let crossingDuration = duration * abs(start) / (abs(start) + abs(end))
        if start > .zero {
            return .init(
                consumedWattHours: start * crossingDuration * 0.5 / 3_600,
                recoveredWattHours: -end * (duration - crossingDuration) * 0.5 / 3_600
            )
        }
        return .init(
            consumedWattHours: end * (duration - crossingDuration) * 0.5 / 3_600,
            recoveredWattHours: -start * crossingDuration * 0.5 / 3_600
        )
    }

    func bucketsStartingIfNeeded(
        at date: Date,
        stateOfChargePercent: Int?
    ) -> [RideEnergyBucket] {
        guard energyBuckets.isEmpty else { return energyBuckets }
        return [makeEnergyBucket(
            at: date,
            stateOfChargePercent: stateOfChargePercent
        )]
    }

    func appendingEnergyBucket(
        at date: Date,
        stateOfChargePercent: Int?
    ) -> [RideEnergyBucket] {
        var buckets = energyBuckets
        if buckets.last?.updatedAt != date {
            buckets.append(makeEnergyBucket(
                at: date,
                stateOfChargePercent: stateOfChargePercent
            ))
        }
        return buckets
    }

    func recordingEnergyBucket(_ recording: EnergyBucketRecording) -> [RideEnergyBucket] {
        var buckets = energyBuckets
        if buckets.isEmpty {
            buckets.append(makeEnergyBucket(
                at: lastElectricalSampleAt ?? recording.date,
                stateOfChargePercent: recording.stateOfChargePercent
            ))
        }
        let index = buckets.index(before: buckets.endIndex)
        let updated = buckets[index].recording(.init(
            date: recording.date,
            distanceKilometers: distanceKilometers,
            stateOfChargePercent: recording.stateOfChargePercent,
            consumedWattHours: recording.energy.consumedWattHours,
            recoveredWattHours: recording.energy.recoveredWattHours
        ))
        buckets[index] = updated
        if updated.shouldRoll(at: recording.date, distanceKilometers: distanceKilometers) {
            buckets.append(makeEnergyBucket(
                at: recording.date,
                stateOfChargePercent: recording.stateOfChargePercent
            ))
        }
        return buckets
    }

    func makeEnergyBucket(
        at date: Date,
        stateOfChargePercent: Int?
    ) -> RideEnergyBucket {
        RideEnergyBucket(
            startedAt: date,
            startDistanceKilometers: distanceKilometers,
            stateOfChargePercent: stateOfChargePercent
        )
    }
}
