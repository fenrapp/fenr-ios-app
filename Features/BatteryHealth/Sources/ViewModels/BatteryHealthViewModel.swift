import BikeDomain
import Foundation
import MeasurementPresentation
import RuntimeConfiguration
import SettingsDomain

@MainActor
public final class BatteryHealthViewModel: ObservableObject {
    @Published public private(set) var viewState = BatteryHealthViewState()

    private let useCases: BatteryHealthUseCases
    private var mapper: BikeBatteryHealthToViewStateMapper
    private let makeMapper: (MeasurementSystem) -> BikeBatteryHealthToViewStateMapper
    private let chargeControlLogStore: BatteryHealthChargeControlLogStore
    private let chargeControlStateUpdater: BatteryHealthChargeControlStateUpdater
    private let chargeControlTaskScheduler: BatteryHealthChargeControlTaskScheduler
    private let captureTimeFormatter: SystemTimeFormatter
    private lazy var chargeControl = BatteryHealthChargeControlCoordinator(
        useCases: useCases,
        logger: chargeControlLogStore,
        stateUpdater: chargeControlStateUpdater,
        taskScheduler: chargeControlTaskScheduler,
        requestRender: { [weak self] in
            self?.scheduleRender()
        }
    )

    private var health = BikeBatteryHealth()
    private var captures: [BatteryDataset: BatteryDatasetCapture] = [:]
    private var streamTasks: [Task<Void, Never>] = []
    private var monitoringTask: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?
    private var isStarted = false
    private var isMonitoring = false
    private var monitorError: String?

    public init(
        useCases: BatteryHealthUseCases,
        mapper: BikeBatteryHealthToViewStateMapper,
        makeMapper: @escaping (MeasurementSystem) -> BikeBatteryHealthToViewStateMapper,
        chargeControlLogStore: BatteryHealthChargeControlLogStore,
        chargeControlStateUpdater: BatteryHealthChargeControlStateUpdater,
        chargeControlTaskScheduler: BatteryHealthChargeControlTaskScheduler,
        captureTimeFormatter: SystemTimeFormatter
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.makeMapper = makeMapper
        self.chargeControlLogStore = chargeControlLogStore
        self.chargeControlStateUpdater = chargeControlStateUpdater
        self.chargeControlTaskScheduler = chargeControlTaskScheduler
        self.captureTimeFormatter = captureTimeFormatter
    }

    deinit {
        streamTasks.forEach { $0.cancel() }
        monitoringTask?.cancel()
        renderTask?.cancel()
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        bindStreams()
        monitoringTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await useCases.startMonitoring.execute()
                guard !Task.isCancelled else { return }
                isMonitoring = true
                render()
            } catch is CancellationError {
                return
            } catch {
                monitorError = String(describing: error)
                render()
            }
        }
        render()
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        streamTasks.forEach { $0.cancel() }
        streamTasks.removeAll()
        monitoringTask?.cancel()
        renderTask?.cancel()
        chargeControl.stop()
        renderTask = nil
        monitoringTask = Task {
            let stopMonitoring = useCases.stopMonitoring
            await stopMonitoring.execute()
        }
        isMonitoring = false
        render()
    }

    public func beginChargePowerDrag() {
        chargeControl.beginPowerDrag()
    }

    public func setDisplayedChargePower(watts: Double) {
        chargeControl.setDisplayedPower(watts: watts)
    }

    public func endChargePowerDrag() {
        chargeControl.endPowerDrag()
    }

    public func beginChargeTargetDrag() {
        chargeControl.beginTargetDrag()
    }

    public func setDisplayedChargeTarget(percent: Double) {
        chargeControl.setDisplayedTarget(percent: percent)
    }

    public func endChargeTargetDrag() {
        chargeControl.endTargetDrag()
    }

    public func captureLogText() -> String {
        let captureLines = captures.values
            .sorted { $0.date > $1.date }
            .map { capture in
                "\(captureTimeFormatter.standardTime(from: capture.date)) | "
                    + "\(capture.dataset.displayName) | \(capture.byteCount) B | \(capture.hex)"
            }
        let chargeLines = chargeControl.logLines.map { "ChargePower | \($0)" }
        return (chargeLines + captureLines).joined(separator: "\n")
    }

    private func bindStreams() {
        let observeHealth = useCases.observeHealth
        streamTasks.append(Task { [weak self] in
            let stream = await observeHealth.execute()
            for await health in stream {
                guard !Task.isCancelled else { return }
                self?.receive(health)
            }
        })
        let observeSettings = useCases.observeSettings
        streamTasks.append(Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled, let self else { return }
                self.mapper = self.makeMapper(settings.measurementSystem)
                self.scheduleRender()
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

    private func receive(_ health: BikeBatteryHealth) {
        self.health = health
        chargeControl.receive(health)
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
            isMonitoring: isMonitoring,
            monitorError: monitorError
        )
        var renderedState = nextState
        renderedState.chargePowerControl = chargeControl.state
        guard renderedState != viewState else { return }
        viewState = renderedState
    }

    private enum RefreshConstants {
        static let renderInterval = FENRRuntimeConstants.BatteryHealth.renderInterval
    }
}
