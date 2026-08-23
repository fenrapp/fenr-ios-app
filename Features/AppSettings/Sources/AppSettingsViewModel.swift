import Combine
import EnvironmentDomain
import SettingsDomain

@MainActor
public final class AppSettingsViewModel: ObservableObject {
    @Published public private(set) var settings = AppSettings()
    @Published public private(set) var locationAuthorizationStatus: LocationAuthorizationStatus = .notDetermined

    private let useCases: AppSettingsUseCases
    private var observationTask: Task<Void, Never>?

    public init(useCases: AppSettingsUseCases) {
        self.useCases = useCases
    }

    deinit { observationTask?.cancel() }

    public func start() {
        guard observationTask == nil else { return }
        let observeSettings = useCases.observeSettings
        observationTask = Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                self?.settings = settings
                await self?.refreshLocationAuthorizationStatus()
            }
        }
        Task { await refreshLocationAuthorizationStatus() }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
    }

    public func selectSpeedSource(_ speedSource: SpeedSource) {
        var updated = settings
        updated.speedSource = speedSource
        settings = updated
        Task { await useCases.saveSettings.execute(updated) }
    }

    public func selectMeasurementSystem(_ measurementSystem: MeasurementSystem) {
        var updated = settings
        updated.measurementSystem = measurementSystem
        settings = updated
        Task { await useCases.saveSettings.execute(updated) }
    }

    public func selectBatteryPackCapacity(_ batteryPackCapacity: BatteryPackCapacity) {
        var updated = settings
        updated.batteryPackCapacity = batteryPackCapacity
        settings = updated
        Task { await useCases.saveSettings.execute(updated) }
    }

    public func requestLocationAccess() {
        Task {
            await useCases.requestLocationAuthorization.execute()
            await refreshLocationAuthorizationStatus()
        }
    }

    private func refreshLocationAuthorizationStatus() async {
        locationAuthorizationStatus = await useCases.locationAuthorizationStatus.execute()
    }
}
