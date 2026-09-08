import BikeDomain
import ChargeControl
import Foundation
import Observation
import RuntimeConfiguration
import SettingsDomain
import VehicleSession

@MainActor
@Observable
public final class BatteryHealthViewModel {
    public private(set) var viewState = BatteryHealthViewState()

    private let useCases: BatteryHealthUseCases
    private let vehicleSession: any VehicleSessionService
    @ObservationIgnored private var mapper: BikeBatteryHealthToViewStateMapper
    private let makeMapper: (MeasurementSystem) -> BikeBatteryHealthToViewStateMapper
    private let chargeControl: ChargeControlSession
    private let captureFormatter: BatteryHealthCaptureFormatter
    @ObservationIgnored private var health = BikeBatteryHealth()
    @ObservationIgnored private var captures: [BatteryDataset: BatteryDatasetCapture] = [:]
    @ObservationIgnored private var streamTasks: [Task<Void, Never>] = []
    private let batteryHealthConsumerID = UUID()
    @ObservationIgnored private var monitoringRequestTask: Task<Void, Never>?
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var chargeControlObservationTask: Task<Void, Never>?
    @ObservationIgnored private var presentationGeneration: UInt64 = 0
    @ObservationIgnored private var isPresentationActive = false
    @ObservationIgnored private var isMonitoring = false
    @ObservationIgnored private var monitorError: String?
    @ObservationIgnored private var activeVehicleIdentity: String?
    @ObservationIgnored private var hasResolvedVehicleIdentity = false
    @ObservationIgnored private var wasVehicleSessionActive = false

    public init(
        useCases: BatteryHealthUseCases,
        vehicleSession: any VehicleSessionService,
        mapper: BikeBatteryHealthToViewStateMapper,
        makeMapper: @escaping (MeasurementSystem) -> BikeBatteryHealthToViewStateMapper,
        chargeControl: ChargeControlSession,
        captureFormatter: BatteryHealthCaptureFormatter
    ) {
        self.useCases = useCases
        self.vehicleSession = vehicleSession
        self.mapper = mapper
        self.makeMapper = makeMapper
        self.chargeControl = chargeControl
        self.captureFormatter = captureFormatter
    }

    deinit {
        streamTasks.forEach { $0.cancel() }
        monitoringRequestTask?.cancel()
        renderTask?.cancel()
        chargeControlObservationTask?.cancel()
    }

    public func setPresentationActive(_ isActive: Bool) {
        guard isPresentationActive != isActive else { return }
        isPresentationActive = isActive
        presentationGeneration &+= 1
        if isActive {
            bindStreams()
            observeChargeControl()
            setBatteryHealthMonitoringRequired(true)
        } else {
            streamTasks.forEach { $0.cancel() }
            streamTasks.removeAll()
            chargeControlObservationTask?.cancel()
            chargeControlObservationTask = nil
            renderTask?.cancel()
            renderTask = nil
            setBatteryHealthMonitoringRequired(false)
            isMonitoring = false
        }
        render()
    }

    public func start() {
        setPresentationActive(true)
    }

    public func stop() {
        setPresentationActive(false)
    }

    public func stopAndWait() async {
        let pendingStreams = streamTasks
        let pendingRender = renderTask
        let pendingChargeControl = chargeControlObservationTask
        stop()
        let stoppedGeneration = presentationGeneration
        let pendingMonitoring = monitoringRequestTask
        for task in pendingStreams { await task.value }
        await pendingRender?.value
        await pendingChargeControl?.value
        await pendingMonitoring?.value
        if presentationGeneration == stoppedGeneration {
            monitoringRequestTask = nil
        }
    }

    public func setChargePowerLimit(watts: Double) {
        chargeControl.setPowerLimit(watts: watts)
    }

    public func setChargeTarget(percent: Double) {
        chargeControl.setTarget(percent: percent)
    }

    public func captureLogText() -> String {
        captureFormatter.export(
            captures: captures,
            chargeAuditLines: chargeControl.logLines
        )
    }
}

private extension BatteryHealthViewModel {
    func observeChargeControl() {
        chargeControlObservationTask?.cancel()
        let stream = chargeControl.observeState()
        let generation = presentationGeneration
        chargeControlObservationTask = Task { [weak self] in
            for await _ in stream {
                guard !Task.isCancelled, let self,
                      self.isPresentationActive, self.presentationGeneration == generation else { return }
                self.scheduleRender()
            }
        }
    }

    func bindStreams() {
        guard streamTasks.isEmpty else { return }
        let vehicleSession = vehicleSession
        streamTasks.append(Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        })
        let observeCaptures = useCases.observeCaptures
        streamTasks.append(Task { [weak self] in
            let stream = await observeCaptures.execute()
            for await capture in stream {
                guard !Task.isCancelled else { return }
                self?.receive(capture)
            }
        })
    }

    func setBatteryHealthMonitoringRequired(_ required: Bool) {
        let previousRequest = monitoringRequestTask
        let vehicleSession = vehicleSession
        let consumerID = batteryHealthConsumerID
        monitoringRequestTask = Task {
            await previousRequest?.value
            guard !required || !Task.isCancelled else { return }
            await vehicleSession.setBatteryHealthMonitoringRequired(required, consumerID: consumerID)
        }
    }

    func receive(_ snapshot: VehicleSessionSnapshot) {
        resetCachesIfVehicleChanged(snapshot)
        resetCachesIfSessionEnded(snapshot.connection.state)
        mapper = makeMapper(snapshot.settings.measurementSystem)
        mergeConfirmedDatasets(snapshot.batteryHealth)
        chargeControl.receive(health)
        switch snapshot.batteryHealthMonitoringState {
        case .inactive, .starting:
            isMonitoring = false
            monitorError = nil
        case .active:
            isMonitoring = true
            monitorError = nil
        case .failed:
            isMonitoring = false
            monitorError = String(localized: .batteryHealthMonitoringError)
        }
        scheduleRender()
    }

    func receive(_ capture: BatteryDatasetCapture) {
        captures[capture.dataset] = capture
        scheduleRender()
    }

    func resetCachesIfVehicleChanged(_ snapshot: VehicleSessionSnapshot) {
        guard snapshot.hasReceivedProfile else { return }
        let nextIdentity = snapshot.profile?.vin
        if hasResolvedVehicleIdentity, nextIdentity != activeVehicleIdentity {
            resetCachedSessionData()
        }
        activeVehicleIdentity = nextIdentity
        hasResolvedVehicleIdentity = true
    }

    func resetCachesIfSessionEnded(_ connectionState: ConnectionState) {
        let isActive = connectionState.isBatteryHealthSessionActive
        if wasVehicleSessionActive, !isActive, connectionState.isBatteryHealthSessionTerminal {
            resetCachedSessionData()
        }
        wasVehicleSessionActive = isActive
    }

    func resetCachedSessionData() {
        health = .init()
        captures.removeAll()
        chargeControl.receive(.init())
    }

    func mergeConfirmedDatasets(_ update: BikeBatteryHealth) {
        if update.stateOfCharge != .unknown { health.stateOfCharge = update.stateOfCharge }
        if update.stateOfHealth != .unknown { health.stateOfHealth = update.stateOfHealth }
        if update.dcBusVoltage != .unknown { health.dcBusVoltage = update.dcBusVoltage }
        if !update.cellVoltages.isEmpty {
            health.cellVoltages = update.cellVoltages
            health.balancingCellIndexes = update.balancingCellIndexes
        }
        if !update.temperatures.isEmpty { health.temperatures = update.temperatures }
        if update.lastUpdated != nil {
            health.chargeState = update.chargeState
            health.chargingStatus = update.chargingStatus
            health.positiveBMSFaultBits = update.positiveBMSFaultBits
            health.negativeBMSFaultBits = update.negativeBMSFaultBits
            health.isVehicleFaultActive = update.isVehicleFaultActive
        }
        if let updated = update.lastUpdated,
           health.lastUpdated.map({ updated >= $0 }) ?? true {
            health.lastUpdated = updated
        }
    }

    func scheduleRender() {
        guard isPresentationActive, renderTask == nil else { return }
        renderTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: RefreshConstants.renderInterval)
            guard !Task.isCancelled, let self else { return }
            renderTask = nil
            render()
        }
    }

    func render() {
        let nextState = mapper.map(
            health: health,
            captures: captures,
            chargeControl: chargeControl.state,
            chargeAuditLines: chargeControl.logLines,
            isMonitoring: isMonitoring,
            monitorError: monitorError
        )
        guard nextState != viewState else { return }
        viewState = nextState
    }

    enum RefreshConstants {
        static let renderInterval = FENRRuntimeConstants.BatteryHealth.renderInterval
    }
}

private extension ConnectionState {
    var isBatteryHealthSessionActive: Bool {
        switch self {
        case .connecting, .discovering, .authenticating, .authenticated,
             .subscribed, .receivingTelemetry, .reconnecting:
            true
        case .idle, .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff,
             .scanning, .pairingResetRequired, .disconnected, .failed:
            false
        }
    }

    var isBatteryHealthSessionTerminal: Bool {
        switch self {
        case .idle, .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff,
             .pairingResetRequired, .disconnected, .failed:
            true
        case .scanning, .connecting, .discovering, .authenticating, .authenticated,
             .subscribed, .receivingTelemetry, .reconnecting:
            false
        }
    }
}
