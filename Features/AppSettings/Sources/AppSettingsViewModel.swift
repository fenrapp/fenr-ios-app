import Combine
import EnvironmentDomain
import SettingsDomain

@MainActor
public final class AppSettingsViewModel: ObservableObject {
    @Published public private(set) var viewState: AppSettingsViewState

    private let useCases: AppSettingsUseCases
    private let mapper: AppSettingsViewStateMapper
    private var settings = AppSettings()
    private var locationAuthorizationStatus: LocationAuthorizationStatus = .notDetermined
    private var observationTask: Task<Void, Never>?
    private var settingsSaveTask: Task<Void, Never>?
    private var locationAuthorizationTask: Task<Void, Never>?

    public init(useCases: AppSettingsUseCases, mapper: AppSettingsViewStateMapper) {
        self.useCases = useCases
        self.mapper = mapper
        viewState = mapper.map(settings: .init(), locationAuthorizationStatus: .notDetermined)
    }

    deinit {
        observationTask?.cancel()
        settingsSaveTask?.cancel()
        locationAuthorizationTask?.cancel()
    }

    public func start() {
        guard observationTask == nil else { return }
        let observeSettings = useCases.observeSettings
        observationTask = Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                self?.settings = settings
                self?.render()
                await self?.refreshLocationAuthorizationStatus()
            }
        }
        locationAuthorizationTask?.cancel()
        locationAuthorizationTask = Task { [weak self] in
            await self?.refreshLocationAuthorizationStatus()
        }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
        locationAuthorizationTask?.cancel()
        locationAuthorizationTask = nil
    }

    public func selectSpeedSource(id: String) {
        guard let speedSource = SpeedSource(rawValue: id) else { return }
        var updated = settings
        updated.speedSource = speedSource
        settings = updated
        save(updated)
    }

    public func selectMeasurementSystem(id: String) {
        guard let measurementSystem = MeasurementSystem(rawValue: id) else { return }
        var updated = settings
        updated.measurementSystem = measurementSystem
        settings = updated
        save(updated)
    }

    public func selectBatteryPackCapacity(id: String) {
        guard let batteryPackCapacity = BatteryPackCapacity(rawValue: id) else { return }
        var updated = settings
        updated.batteryPackCapacity = batteryPackCapacity
        settings = updated
        save(updated)
    }

    public func requestLocationAccess() {
        guard let requestLocationAuthorization = useCases.requestLocationAuthorization else { return }
        locationAuthorizationTask?.cancel()
        locationAuthorizationTask = Task { [weak self] in
            await requestLocationAuthorization.execute()
            guard !Task.isCancelled else { return }
            await self?.refreshLocationAuthorizationStatus()
        }
    }

    private func refreshLocationAuthorizationStatus() async {
        guard let locationAuthorizationStatus = useCases.locationAuthorizationStatus else { return }
        self.locationAuthorizationStatus = await locationAuthorizationStatus.execute()
        render()
    }

    private func save(_ settings: AppSettings) {
        render()
        let previousSaveTask = settingsSaveTask
        let saveSettings = useCases.saveSettings
        settingsSaveTask = Task {
            await previousSaveTask?.value
            guard !Task.isCancelled else { return }
            await saveSettings.execute(settings)
        }
    }

    private func render() {
        viewState = mapper.map(
            settings: settings,
            locationAuthorizationStatus: locationAuthorizationStatus
        )
    }
}
