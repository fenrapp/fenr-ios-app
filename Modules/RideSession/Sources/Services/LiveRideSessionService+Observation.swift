import Foundation
import VehicleSession

extension LiveRideSessionService {
    func observeVehicleSession() {
        let vehicleSession = vehicleSession
        observationTasks.append(Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                await self?.receive(snapshot)
            }
        })
    }

    func receive(_ snapshot: VehicleSessionSnapshot) async {
        let wasReceiving = isReceivingTelemetry
        let previouslyReceivedProfile = vehicleSnapshot.hasReceivedProfile
        vehicleSnapshot = snapshot

        if wasReceiving, !isReceivingTelemetry, let rebased = recorder.trip?.rebasingElectrical() {
            recorder.restore(rebased)
            lastElectricalSampleDate = nil
            await persistIfNeeded(force: true)
        }

        if snapshot.hasReceivedProfile {
            await receiveProfileVIN(snapshot.profile?.vin, wasReceived: previouslyReceivedProfile)
        }
        await promoteIdentityIfPossible(snapshot.telemetry.vin)
        prepareIfNeeded()
        await updateCurrentTrip()
        publish()
    }

    private func receiveProfileVIN(_ vin: String?, wasReceived: Bool) async {
        if let vin, let confirmedVIN = identityResolver.confirmedVIN(from: vin) {
            switch recorder.context.vehicleIdentity {
            case .vin(let activeVIN) where activeVIN != confirmedVIN:
                await transitionToVehicle(identity: .vin(confirmedVIN))
            case .temporary:
                await promoteIdentityIfPossible(confirmedVIN)
            case .vin:
                break
            }
        } else if wasReceived, recorder.context.vehicleIdentity.confirmedVIN != nil {
            await transitionToVehicle(identity: .temporary(UUID()))
        }
    }

    func promoteIdentityIfPossible(_ candidate: String) async {
        guard let vin = identityResolver.confirmedVIN(from: candidate) else { return }
        switch recorder.context.vehicleIdentity {
        case .vin:
            return
        case .temporary(let temporaryID):
            recorder.promote(to: vin)
            publish()
            if await persistence.promoteTemporaryIdentity(temporaryID, toVIN: vin) {
                historyRevision += 1
                publish()
            }
        }
    }
}
