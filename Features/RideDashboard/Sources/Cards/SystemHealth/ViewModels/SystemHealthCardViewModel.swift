import Combine
import Foundation
import VehicleSession

@MainActor
public final class SystemHealthCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardSystemHealthViewData()

    private let vehicleSession: any VehicleSessionService
    private let mapper: SystemHealthCardMapper
    private let consumerID = UUID()
    private var snapshot = VehicleSessionSnapshot()
    private var observationTask: Task<Void, Never>?
    private var monitoringRequestTask: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?
    private var isVisible = false
    private var isRequestingBatteryHealth = false
    private var hasCachedHealthData = false

    public init(
        vehicleSession: any VehicleSessionService,
        mapper: SystemHealthCardMapper
    ) {
        self.vehicleSession = vehicleSession
        self.mapper = mapper
    }

    deinit {
        observationTask?.cancel()
        renderTask?.cancel()
        guard isRequestingBatteryHealth else { return }
        let previousRequest = monitoringRequestTask
        let vehicleSession = vehicleSession
        let consumerID = consumerID
        Task {
            await previousRequest?.value
            await vehicleSession.setBatteryHealthMonitoringRequired(false, consumerID: consumerID)
        }
    }

    func setIsVisible(_ isVisible: Bool) {
        guard self.isVisible != isVisible else { return }
        self.isVisible = isVisible
        if isVisible {
            observeIfNeeded()
            setMonitoringRequired(true)
        } else {
            observationTask?.cancel()
            observationTask = nil
            renderTask?.cancel()
            renderTask = nil
            setMonitoringRequired(false)
        }
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardSystemHealthViewData) {
        self.viewState = viewState
    }
#endif
}

private extension SystemHealthCardViewModel {
    func observeIfNeeded() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self, vehicleSession] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
    }

    func receive(_ snapshot: VehicleSessionSnapshot) {
        self.snapshot = snapshot
        scheduleRender()
    }

    func scheduleRender() {
        guard isVisible, renderTask == nil else { return }
        renderTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Constants.renderInterval)
            guard !Task.isCancelled, let self else { return }
            renderTask = nil
            render()
        }
    }

    func render() {
        guard isVisible else { return }
        if hasCachedHealthData, shouldKeepCachedState(for: snapshot) { return }
        let next = mapper.map(snapshot)
        if !snapshot.batteryHealth.cellVoltages.isEmpty || snapshot.batteryHealth.isBMSFaultActive {
            hasCachedHealthData = true
        }
        guard next != viewState else { return }
        viewState = next
    }

    func shouldKeepCachedState(for snapshot: VehicleSessionSnapshot) -> Bool {
        if case .failed = snapshot.batteryHealthMonitoringState { return false }
        return snapshot.batteryHealth.cellVoltages.isEmpty
            && !snapshot.batteryHealth.isBMSFaultActive
    }

    func setMonitoringRequired(_ required: Bool) {
        guard required != isRequestingBatteryHealth else { return }
        isRequestingBatteryHealth = required
        let previousRequest = monitoringRequestTask
        let vehicleSession = vehicleSession
        let consumerID = consumerID
        monitoringRequestTask = Task {
            await previousRequest?.value
            guard !Task.isCancelled else { return }
            await vehicleSession.setBatteryHealthMonitoringRequired(required, consumerID: consumerID)
        }
    }

    enum Constants {
        static let renderInterval = Duration.milliseconds(500)
    }
}
