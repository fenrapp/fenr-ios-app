import BikeDomain
import Foundation
import SettingsDomain

@MainActor
public final class BatteryHealthViewModel: ObservableObject {
    @Published public private(set) var viewState = BatteryHealthViewState()

    private let useCases: BatteryHealthUseCases
    private var mapper: BikeBatteryHealthToViewStateMapper
    private let makeMapper: (MeasurementSystem) -> BikeBatteryHealthToViewStateMapper
    private var health = BikeBatteryHealth()
    private var captures: [BatteryDataset: BatteryDatasetCapture] = [:]
    private var streamTasks: [Task<Void, Never>] = []
    private var monitoringTask: Task<Void, Never>?
    private var isStarted = false
    private var isMonitoring = false
    private var monitorError: String?

    public init(
        useCases: BatteryHealthUseCases,
        mapper: BikeBatteryHealthToViewStateMapper,
        makeMapper: @escaping (MeasurementSystem) -> BikeBatteryHealthToViewStateMapper
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.makeMapper = makeMapper
    }

    deinit {
        streamTasks.forEach { $0.cancel() }
        monitoringTask?.cancel()
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
        monitoringTask = Task {
            let stopMonitoring = useCases.stopMonitoring
            await stopMonitoring.execute()
        }
        isMonitoring = false
        render()
    }

    public func captureLogText() -> String {
        captures.values
            .sorted { $0.date > $1.date }
            .map { capture in
                "\(capture.date.formatted(date: .omitted, time: .standard)) | "
                    + "\(capture.dataset.displayName) | \(capture.byteCount) B | \(capture.hex)"
            }
            .joined(separator: "\n")
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
                self.render()
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
        render()
    }

    private func receive(_ capture: BatteryDatasetCapture) {
        captures[capture.dataset] = capture
        render()
    }

    private func render() {
        let nextState = mapper.map(
            health: health,
            captures: captures,
            isMonitoring: isMonitoring,
            monitorError: monitorError
        )
        guard nextState != viewState else { return }
        viewState = nextState
    }
}
