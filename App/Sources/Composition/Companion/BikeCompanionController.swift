import Foundation
import VehicleSession
import WatchCompanionDomain

@MainActor
final class BikeCompanionController {
    private let vehicleSession: any VehicleSessionService
    private let companion: any CompanionSnapshotPublishing
    private let mapper: BikeCompanionSnapshotMapper
    private let now: @Sendable () -> Date
    private let monitoringID: UUID
    private var observationTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var restartAfterStop = false
    private var monitoringRequired = false

    init(
        vehicleSession: any VehicleSessionService,
        companion: any CompanionSnapshotPublishing,
        mapper: BikeCompanionSnapshotMapper,
        now: @escaping @Sendable () -> Date,
        monitoringID: UUID
    ) {
        self.vehicleSession = vehicleSession
        self.companion = companion
        self.mapper = mapper
        self.now = now
        self.monitoringID = monitoringID
    }

    deinit {
        observationTask?.cancel()
        // An in-flight stop finishes releasing its lease independently of this owner.
    }

    func start() {
        if stopTask != nil {
            restartAfterStop = true
            return
        }
        guard observationTask == nil else { return }
        companion.activate()
        observationTask = Task { [weak self, vehicleSession, monitoringID] in
            let stream = await vehicleSession.observe()
            for await source in stream {
                guard !Task.isCancelled, let self else { break }
                let snapshot = mapper.map(source, now: now())
                let needsMonitoring = snapshot.bikeConnected && snapshot.isCharging
                if monitoringRequired != needsMonitoring {
                    monitoringRequired = needsMonitoring
                    await vehicleSession.setBatteryHealthMonitoringRequired(needsMonitoring, consumerID: monitoringID)
                    guard !Task.isCancelled else { break }
                }
                companion.publish(snapshot)
            }
            // This lease cleanup must finish even when the controller has been released.
            await vehicleSession.setBatteryHealthMonitoringRequired(false, consumerID: monitoringID)
        }
    }

    func stop() async {
        if let stopTask {
            await stopTask.value
            return
        }
        let pendingObservation = observationTask
        pendingObservation?.cancel()
        stopTask = Task { [weak self, companion, now] in
            await pendingObservation?.value
            companion.publish(CompanionSnapshot(generatedAt: now()))
            self?.completeStop()
        }
        await stopTask?.value
    }

    private func completeStop() {
        observationTask = nil
        monitoringRequired = false
        stopTask = nil
        if restartAfterStop {
            restartAfterStop = false
            start()
        }
    }
}
