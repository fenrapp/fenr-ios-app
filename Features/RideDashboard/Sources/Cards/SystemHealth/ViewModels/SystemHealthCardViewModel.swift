import BikeDomain
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
    private var cachedVehicleIdentity: String?
    private var cachedBatteryHealth = BikeBatteryHealth()
    private var cachedInverterTemperatures: [Double?] = []

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
        if let vin = snapshot.profile?.vin, vin != cachedVehicleIdentity {
            cachedVehicleIdentity = vin
            cachedBatteryHealth = .init()
            cachedInverterTemperatures = []
        }
        mergeConfirmedDatasets(from: snapshot)
        self.snapshot = presentationSnapshot(from: snapshot)
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
        let next = mapper.map(snapshot)
        guard next != viewState else { return }
        viewState = next
    }

    func mergeConfirmedDatasets(from snapshot: VehicleSessionSnapshot) {
        let health = snapshot.batteryHealth
        if health.stateOfCharge != .unknown {
            cachedBatteryHealth.stateOfCharge = health.stateOfCharge
        }
        if health.stateOfHealth != .unknown {
            cachedBatteryHealth.stateOfHealth = health.stateOfHealth
        }
        if health.dcBusVoltage != .unknown {
            cachedBatteryHealth.dcBusVoltage = health.dcBusVoltage
        }
        if !health.cellVoltages.isEmpty {
            cachedBatteryHealth.cellVoltages = health.cellVoltages
            cachedBatteryHealth.balancingCellIndexes = health.balancingCellIndexes
        }
        if !health.temperatures.isEmpty {
            cachedBatteryHealth.temperatures = health.temperatures
        }
        if health.lastUpdated != nil {
            cachedBatteryHealth.chargeState = health.chargeState
            cachedBatteryHealth.chargingStatus = health.chargingStatus
            cachedBatteryHealth.positiveBMSFaultBits = health.positiveBMSFaultBits
            cachedBatteryHealth.negativeBMSFaultBits = health.negativeBMSFaultBits
            cachedBatteryHealth.isVehicleFaultActive = health.isVehicleFaultActive
            cachedBatteryHealth.lastUpdated = health.lastUpdated
        }
        if !snapshot.telemetry.inverterTemperaturesCelsius.isEmpty {
            cachedInverterTemperatures = snapshot.telemetry.inverterTemperaturesCelsius
        }
    }

    func presentationSnapshot(from snapshot: VehicleSessionSnapshot) -> VehicleSessionSnapshot {
        var telemetry = snapshot.telemetry
        telemetry.inverterTemperaturesCelsius = cachedInverterTemperatures
        return .init(
            telemetry: telemetry,
            connection: snapshot.connection,
            settings: snapshot.settings,
            profile: snapshot.profile,
            resolvedSpeedKilometersPerHour: snapshot.resolvedSpeedKilometersPerHour,
            speedSource: snapshot.speedSource,
            isGPSAvailable: snapshot.isGPSAvailable,
            batteryHealth: cachedBatteryHealth,
            batteryHealthMonitoringState: snapshot.batteryHealthMonitoringState,
            motion: snapshot.motion,
            hasReceivedSettings: snapshot.hasReceivedSettings,
            hasReceivedProfile: snapshot.hasReceivedProfile
        )
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
