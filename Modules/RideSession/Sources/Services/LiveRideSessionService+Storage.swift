import Foundation
import RideSessionDomain

extension LiveRideSessionService {
    func transitionToVehicle(identity: RideVehicleIdentity) async {
        guard stopTask == nil else { return }
        await completeCurrentTrip()
        recorder = CurrentTripRecorder(context: .init(
            applicationSessionID: recorder.context.applicationSessionID,
            vehicleIdentity: identity
        ))
        lastElectricalSampleDate = nil
        lastMotionSampleDate = nil
        lastPersistenceDate = nil
        isPrepared = false
    }

    func startTickerIfNeeded() {
        guard stopTask == nil, tickerTask == nil else { return }
        let sleep = sleep
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await sleep(Constants.tickInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                guard await self?.tick() == true else { return }
            }
        }
    }

    func tick() async -> Bool {
        guard stopTask == nil else {
            tickerTask = nil
            return false
        }
        guard updateTripAtCurrentTime() != nil else {
            tickerTask = nil
            return false
        }
        await persistIfNeeded(force: false)
        publish()
        return true
    }

    func persistIfNeeded(force: Bool) async {
        guard let trip = recorder.trip else { return }
        if !force,
           trip.updatedAt.timeIntervalSince(lastPersistenceDate ?? .distantPast)
            < Constants.persistenceInterval { return }
        lastPersistenceDate = trip.updatedAt
        await persistence.saveActiveTrip(trip)
    }

    func updateCurrentTrip() async {
        guard stopTask == nil, isPrepared, isReceivingTelemetry else { return }
        let previousTripID = recorder.trip?.id
        guard var trip = recorder.record(
            runState: vehicleSnapshot.telemetry.runState,
            at: now(),
            odometerKilometers: vehicleSnapshot.telemetry.odometer.kilometers,
            speedKilometersPerHour: resolvedSpeed()
        ) else { return }

        if let sampleDate = vehicleSnapshot.telemetry.batteryTelemetry.signalsUpdatedAt,
           sampleDate != lastElectricalSampleDate,
           let powerWatts = vehicleSnapshot.telemetry.powerTelemetry.electricalPowerWatts {
            trip = trip.updatingElectrical(
                at: sampleDate,
                powerWatts: powerWatts,
                stateOfChargePercent: vehicleSnapshot.telemetry.batteryLevel.percent
            )
            recorder.restore(trip)
            lastElectricalSampleDate = sampleDate
            appendLivePowerSample(date: sampleDate, powerWatts: powerWatts)
        }

        if let sampleDate = vehicleSnapshot.motion.observedAt,
           sampleDate != lastMotionSampleDate,
           vehicleSnapshot.motion.availability == .available,
           let roll = vehicleSnapshot.motion.rollDegrees,
           let pitch = vehicleSnapshot.motion.pitchDegrees {
            trip = trip.updatingMotion(rollDegrees: roll, pitchDegrees: pitch)
            recorder.restore(trip)
            lastMotionSampleDate = sampleDate
        }

        if previousTripID == nil {
            startTickerIfNeeded()
            await persistIfNeeded(force: true)
        } else {
            await persistIfNeeded(force: false)
        }
    }

    func updateTripAtCurrentTime() -> RideTrip? {
        recorder.tick(at: now(), speedKilometersPerHour: resolvedSpeed())
    }

    func appendLivePowerSample(date: Date, powerWatts: Double) {
        if let last = livePowerSamples.last,
           date.timeIntervalSince(last.date) < Constants.minimumLiveSampleInterval {
            livePowerSamples[livePowerSamples.index(before: livePowerSamples.endIndex)] = .init(
                date: date,
                powerWatts: powerWatts
            )
        } else {
            livePowerSamples.append(.init(date: date, powerWatts: powerWatts))
        }
        let cutoff = date.addingTimeInterval(-Constants.liveSampleWindow)
        livePowerSamples.removeAll { $0.date < cutoff }
        if livePowerSamples.count > Constants.maximumLiveSampleCount {
            livePowerSamples.removeFirst(livePowerSamples.count - Constants.maximumLiveSampleCount)
        }
    }

    func prepareIfNeeded() {
        guard stopTask == nil,
              vehicleSnapshot.hasReceivedProfile,
              !isPrepared,
              preparationTask == nil
        else { return }
        let prepare = useCases.prepare
        let context = recorder.context
        preparationTask = Task { [weak self] in
            let restoredTrip = await prepare.execute(context: context)
            guard !Task.isCancelled else { return }
            await self?.finishPreparation(restoredTrip, context: context)
        }
    }

    func finishPreparation(_ restoredTrip: RideTrip?, context: BikeSessionContext) async {
        preparationTask = nil
        guard stopTask == nil else { return }
        guard recorder.context == context else {
            prepareIfNeeded()
            return
        }
        isPrepared = true
        recorder.restore(restoredTrip)
        if let restoredTrip {
            lastPersistenceDate = restoredTrip.updatedAt
            lastElectricalSampleDate = nil
            lastMotionSampleDate = nil
            if !restoredTrip.isPaused { startTickerIfNeeded() }
        }
        await updateCurrentTrip()
        publish()
    }
}
