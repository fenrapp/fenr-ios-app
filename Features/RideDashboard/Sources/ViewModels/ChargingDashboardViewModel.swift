import BikeDomain
import ChargeControl
import Combine
import Foundation
import SettingsDomain
import VehicleSession

@MainActor
public final class ChargingDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = ChargingDashboardViewState()

    private let vehicleSession: any VehicleSessionService
    private let chargeControl: ChargeControlSession
    private let makeMapper: @Sendable (AppSettings, String?) -> ChargingDashboardMapper
    private var mapper: ChargingDashboardMapper
    private var snapshot = VehicleSessionSnapshot()
    private var observationTask: Task<Void, Never>?
    private let batteryHealthConsumerID = UUID()
    private var isRequestingBatteryHealth = false
    private var batteryHealthRequirementTask: Task<Void, Never>?
    private var chargeControlCancellable: AnyCancellable?
    private var hasCanonicalTelemetry = false

    public init(
        vehicleSession: any VehicleSessionService,
        chargeControl: ChargeControlSession,
        mapper: ChargingDashboardMapper,
        makeMapper: @escaping @Sendable (AppSettings, String?) -> ChargingDashboardMapper
    ) {
        self.vehicleSession = vehicleSession
        self.chargeControl = chargeControl
        self.mapper = mapper
        self.makeMapper = makeMapper
        chargeControlCancellable = chargeControl.$state
            .dropFirst()
            .sink { [weak self] _ in self?.render() }
    }

    deinit {
        observationTask?.cancel()
        guard isRequestingBatteryHealth else { return }
        let previousRequirement = batteryHealthRequirementTask
        let vehicleSession = vehicleSession
        let consumerID = batteryHealthConsumerID
        Task {
            await previousRequirement?.value
            await vehicleSession.setBatteryHealthMonitoringRequired(false, consumerID: consumerID)
        }
    }

    func start() {
        guard observationTask == nil else { return }
        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
    }

    func stop() {
        suspend()
        snapshot = .init()
        viewState = .init()
    }

    func suspend() {
        observationTask?.cancel()
        observationTask = nil
        setBatteryHealthRequired(false)
        hasCanonicalTelemetry = false
        chargeControl.receive(.init())
        render()
    }

    func setChargePowerLimit(watts: Double) {
        guard hasCanonicalTelemetry else { return }
        chargeControl.setPowerLimit(watts: watts)
    }

    func setChargeTarget(percent: Double) {
        guard hasCanonicalTelemetry else { return }
        chargeControl.setTarget(percent: percent)
    }

#if DEBUG
    func setPreviewState(_ viewState: ChargingDashboardViewState) {
        self.viewState = viewState
    }
#endif

    private func receive(_ snapshot: VehicleSessionSnapshot) {
        guard Self.hasCanonicalTelemetry(snapshot) else {
            hasCanonicalTelemetry = false
            chargeControl.receive(.init())
            if Self.isTerminal(snapshot.connection.state) {
                setBatteryHealthRequired(false)
            }
            render()
            return
        }
        hasCanonicalTelemetry = true
        self.snapshot = snapshot
        mapper = makeMapper(snapshot.settings, snapshot.profile?.vin)
        chargeControl.receive(snapshot.batteryHealth)
        setBatteryHealthRequired(snapshot.telemetry.statusFlags.isChargerConnected)
        render()
    }

    private static func hasCanonicalTelemetry(_ snapshot: VehicleSessionSnapshot) -> Bool {
        snapshot.isCanonicalTelemetryAvailable
    }

    private static func isTerminal(_ state: ConnectionState) -> Bool {
        switch state {
        case .bluetoothUnavailable,
             .bluetoothUnauthorized,
             .bluetoothPoweredOff,
             .pairingResetRequired,
             .disconnected,
             .failed:
            true
        case .idle,
             .scanning,
             .connecting,
             .discovering,
             .authenticating,
             .authenticated,
             .subscribed,
             .receivingTelemetry,
             .reconnecting:
            false
        }
    }

    private func setBatteryHealthRequired(_ required: Bool) {
        guard required != isRequestingBatteryHealth else { return }
        isRequestingBatteryHealth = required
        let previousRequirement = batteryHealthRequirementTask
        let vehicleSession = vehicleSession
        let consumerID = batteryHealthConsumerID
        batteryHealthRequirementTask = Task {
            await previousRequirement?.value
            await vehicleSession.setBatteryHealthMonitoringRequired(required, consumerID: consumerID)
        }
    }

    private func render() {
        let nextViewState = mapper.map(
            telemetry: snapshot.telemetry,
            batteryHealth: snapshot.batteryHealth,
            chargeControl: chargeControl.state
        )
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }
}
