import BikeDomain
import ChargeControl
import Combine
import Foundation
import RuntimeConfiguration
import SettingsDomain
import VehicleSession

@MainActor
public final class BatteryHealthViewModel: ObservableObject {
    @Published public private(set) var viewState = BatteryHealthViewState()

    private let useCases: BatteryHealthUseCases
    private let vehicleSession: any VehicleSessionService
    private var mapper: BikeBatteryHealthToViewStateMapper
    private let makeMapper: (MeasurementSystem) -> BikeBatteryHealthToViewStateMapper
    private let chargeControl: ChargeControlSession
    private let captureTimeFormatStyle: Date.FormatStyle
    private var health = BikeBatteryHealth()
    private var captures: [BatteryDataset: BatteryDatasetCapture] = [:]
    private var streamTasks: [Task<Void, Never>] = []
    private let batteryHealthConsumerID = UUID()
    private var monitoringRequestTask: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?
    private var chargeControlCancellable: AnyCancellable?
    private var isStarted = false
    private var isMonitoring = false
    private var monitorError: String?

    public init(
        useCases: BatteryHealthUseCases,
        vehicleSession: any VehicleSessionService,
        mapper: BikeBatteryHealthToViewStateMapper,
        makeMapper: @escaping (MeasurementSystem) -> BikeBatteryHealthToViewStateMapper,
        chargeControl: ChargeControlSession,
        captureTimeFormatStyle: Date.FormatStyle
    ) {
        self.useCases = useCases
        self.vehicleSession = vehicleSession
        self.mapper = mapper
        self.makeMapper = makeMapper
        self.chargeControl = chargeControl
        self.captureTimeFormatStyle = captureTimeFormatStyle
        chargeControlCancellable = chargeControl.$state
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleRender() }
    }

    deinit {
        streamTasks.forEach { $0.cancel() }
        monitoringRequestTask?.cancel()
        renderTask?.cancel()
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        bindStreams()
        setBatteryHealthMonitoringRequired(true)
        render()
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        streamTasks.forEach { $0.cancel() }
        streamTasks.removeAll()
        renderTask?.cancel()
        renderTask = nil
        setBatteryHealthMonitoringRequired(false)
        isMonitoring = false
        render()
    }

    public func setChargePowerLimit(watts: Double) {
        chargeControl.setPowerLimit(watts: watts)
    }

    public func setChargeTarget(percent: Double) {
        chargeControl.setTarget(percent: percent)
    }

    public func captureLogText() -> String {
        let captureLines = captures.values
            .sorted { $0.date > $1.date }
            .map { capture in
                "\(capture.date.formatted(captureTimeFormatStyle)) | "
                    + "\(capture.dataset.displayName) | \(capture.byteCount) B | \(capture.hex)"
            }
        let chargeLines = chargeControl.logLines.map { "ChargePower | \($0)" }
        return (chargeLines + captureLines).joined(separator: "\n")
    }

    private func bindStreams() {
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

    private func setBatteryHealthMonitoringRequired(_ required: Bool) {
        let previousRequest = monitoringRequestTask
        let vehicleSession = vehicleSession
        let consumerID = batteryHealthConsumerID
        monitoringRequestTask = Task {
            await previousRequest?.value
            guard !Task.isCancelled else { return }
            await vehicleSession.setBatteryHealthMonitoringRequired(
                required,
                consumerID: consumerID
            )
        }
    }

    private func receive(_ health: BikeBatteryHealth) {
        self.health = health
        chargeControl.receive(health)
        scheduleRender()
    }

    private func receive(_ snapshot: VehicleSessionSnapshot) {
        mapper = makeMapper(snapshot.settings.measurementSystem)
        receive(snapshot.batteryHealth)
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

    private func receive(_ capture: BatteryDatasetCapture) {
        captures[capture.dataset] = capture
        scheduleRender()
    }

    // BMS frames arrive quickly enough to interrupt an active ScrollView gesture.
    // Keep the latest data, but publish it to SwiftUI at a rider-readable cadence.
    private func scheduleRender() {
        guard renderTask == nil else { return }
        renderTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: RefreshConstants.renderInterval)
            guard !Task.isCancelled, let self else { return }
            renderTask = nil
            render()
        }
    }

    private func render() {
        let nextState = mapper.map(
            health: health,
            captures: captures,
            chargeControl: chargeControl.state,
            isMonitoring: isMonitoring,
            monitorError: monitorError
        )
        guard nextState != viewState else { return }
        viewState = nextState
    }

    private enum RefreshConstants {
        static let renderInterval = FENRRuntimeConstants.BatteryHealth.renderInterval
    }
}
