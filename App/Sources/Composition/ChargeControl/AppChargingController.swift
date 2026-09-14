import BikeDomain
import ChargeControl
import Foundation
import VehicleSession

@MainActor
final class AppChargingController {
    private let vehicleSession: any VehicleSessionService
    private let session: ChargeControlSession
    private let preferences: ChargingPreferencesController
    private var observationTask: Task<Void, Never>?
    private let consumerID = UUID()
    private var requiresMonitoring = false
    private var monitoringTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?

    init(
        vehicleSession: any VehicleSessionService,
        session: ChargeControlSession,
        preferences: ChargingPreferencesController
    ) {
        self.vehicleSession = vehicleSession
        self.session = session
        self.preferences = preferences
    }

    deinit {
        observationTask?.cancel()
        stateTask?.cancel()
        guard requiresMonitoring else { return }
        let previous = monitoringTask
        // Release this consumer after its owner is destroyed; this never publishes UI state.
        Task { [vehicleSession, consumerID] in
            await previous?.value
            await vehicleSession.setBatteryHealthMonitoringRequired(false, consumerID: consumerID)
        }
    }

    func start() {
        guard observationTask == nil else { return }
        stateTask = Task { [session, preferences] in
            for await state in preferences.observe() {
                guard !Task.isCancelled else { return }
                session.receiveManaged(state)
            }
        }
        observationTask = Task { [weak self, vehicleSession, preferences] in
            let snapshots = await vehicleSession.observe()
            for await snapshot in snapshots {
                guard !Task.isCancelled else { return }
                let ready: Bool
                switch snapshot.connection.state {
                case .receivingTelemetry:
                    ready = snapshot.isCanonicalTelemetryAvailable
                        && snapshot.profile?.vin == snapshot.telemetry.vin
                default: ready = false
                }
                let connected = ready && snapshot.telemetry.statusFlags.isChargerConnected
                self?.setMonitoring(connected)
                let charger = connected ? snapshot.batteryHealth.chargingStatus?.chargerType : nil
                preferences.receive(.init(
                    vin: snapshot.profile?.vin, isReady: ready,
                    isChargerConnected: connected, charger: charger
                ))
            }
        }
    }

    private func setMonitoring(_ required: Bool) {
        guard required != requiresMonitoring else { return }
        requiresMonitoring = required
        let previous = monitoringTask
        monitoringTask = Task { [vehicleSession, consumerID] in
            await previous?.value
            await vehicleSession.setBatteryHealthMonitoringRequired(required, consumerID: consumerID)
        }
    }

    func stopAndWait() async {
        let observation = observationTask
        let state = stateTask
        observation?.cancel()
        state?.cancel()
        await observation?.value
        await state?.value
        await preferences.stopAndWait()
        setMonitoring(false)
        await monitoringTask?.value
        monitoringTask = nil
        observationTask = nil
        stateTask = nil
    }
}
