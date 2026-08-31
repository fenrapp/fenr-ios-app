import BikeDomain
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
    private var profile: BikeProfile?
    private var connection = BikeConnection()
    private var isVerifyingPowerTier = false
    private var powerTierVerificationMessage: String?
    private var observationTask: Task<Void, Never>?
    private var settingsSaveTask: Task<Void, Never>?
    private var locationAuthorizationTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var profileSaveTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var powerTierTask: Task<Void, Never>?

    public init(useCases: AppSettingsUseCases, mapper: AppSettingsViewStateMapper) {
        self.useCases = useCases
        self.mapper = mapper
        viewState = mapper.map(settings: .init(), locationAuthorizationStatus: .notDetermined)
    }

    deinit {
        observationTask?.cancel()
        settingsSaveTask?.cancel()
        locationAuthorizationTask?.cancel()
        profileTask?.cancel()
        profileSaveTask?.cancel()
        connectionTask?.cancel()
        powerTierTask?.cancel()
    }

    public func start() {
        guard observationTask == nil else { return }
        let observeSettings = useCases.settings.observe
        observationTask = Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled, let self else { return }
                guard self.settings != settings else { continue }
                self.settings = settings
                self.render()
                await self.refreshLocationAuthorizationStatus()
            }
        }
        locationAuthorizationTask?.cancel()
        locationAuthorizationTask = Task { [weak self] in
            await self?.refreshLocationAuthorizationStatus()
        }
        observeProfile()
        observeConnection()
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
        locationAuthorizationTask?.cancel()
        locationAuthorizationTask = nil
        profileTask?.cancel()
        profileTask = nil
        connectionTask?.cancel()
        connectionTask = nil
        powerTierTask?.cancel()
        powerTierTask = nil
        if isVerifyingPowerTier {
            isVerifyingPowerTier = false
            render()
        }
    }

    public func selectSpeedSource(id: String) {
        guard let speedSource = SpeedSource(rawValue: id) else { return }
        var updated = settings
        updated.speedSource = speedSource
        settings = updated
        save(updated)
    }

    public func selectDashboardProgressBarMode(id: String) {
        guard let mode = DashboardProgressBarMode(rawValue: id) else { return }
        var updated = settings
        updated.dashboardProgressBarMode = mode
        settings = updated
        save(updated)
    }

    public func selectDashboardBatteryIndicatorMode(id: String) {
        guard let mode = DashboardBatteryIndicatorMode(rawValue: id) else { return }
        var updated = settings
        updated.dashboardBatteryIndicatorMode = mode
        settings = updated
        save(updated)
    }

    public func selectDashboardDeviceBatteryDisplayMode(id: String) {
        guard let mode = DashboardDeviceBatteryDisplayMode(rawValue: id) else { return }
        var updated = settings
        updated.dashboardDeviceBatteryDisplayMode = mode
        settings = updated
        save(updated)
    }

    public func setShowsDashboardTemperatures(_ isVisible: Bool) {
        var updated = settings
        updated.showsDashboardTemperatures = isVisible
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
        guard let batteryPackCapacity = BatteryPackCapacity(rawValue: id), let vin = profile?.vin else { return }
        var updated = settings
        updated.setBatteryPackCapacity(batteryPackCapacity, forVIN: vin)
        settings = updated
        save(updated)
    }

    public func requestLocationAccess() {
        guard let requestLocationAuthorization = useCases.location?.requestAuthorization else { return }
        locationAuthorizationTask?.cancel()
        locationAuthorizationTask = Task { [weak self] in
            await requestLocationAuthorization.execute()
            guard !Task.isCancelled else { return }
            await self?.refreshLocationAuthorizationStatus()
        }
    }

    public func selectDeclaredPowerTier(id: String) {
        guard let tier = BikeDeclaredPowerTier(rawValue: id), var profile else { return }
        profile.declaredPowerTier = tier
        self.profile = profile
        powerTierVerificationMessage = nil
        render()
        guard let save = useCases.profile?.save else { return }
        let previousSaveTask = profileSaveTask
        profileSaveTask = Task {
            await previousSaveTask?.value
            guard !Task.isCancelled else { return }
            await save.execute(profile)
        }
    }

    public func verifyPowerTierWithBike() {
        guard let refresh = useCases.powerTierVerification?.refreshPowerModes,
              !isVerifyingPowerTier else { return }
        isVerifyingPowerTier = true
        powerTierVerificationMessage = nil
        render()
        powerTierTask?.cancel()
        powerTierTask = Task { [weak self] in
            do {
                try await refresh.execute()
                try Task.checkCancellation()
                guard let self else { return }
                self.isVerifyingPowerTier = false
                self.powerTierVerificationMessage = "Bike verification completed"
                self.render()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.isVerifyingPowerTier = false
                self.powerTierVerificationMessage = "Verification failed: \(error.localizedDescription)"
                self.render()
            }
        }
    }

    private func refreshLocationAuthorizationStatus() async {
        guard let locationAuthorizationStatus = useCases.location?.authorizationStatus else { return }
        self.locationAuthorizationStatus = await locationAuthorizationStatus.execute()
        guard !Task.isCancelled else { return }
        render()
    }

    private func save(_ settings: AppSettings) {
        render()
        let previousSaveTask = settingsSaveTask
        let saveSettings = useCases.settings.save
        settingsSaveTask = Task {
            await previousSaveTask?.value
            guard !Task.isCancelled else { return }
            await saveSettings.execute(settings)
        }
    }

    private func observeProfile() {
        guard let observe = useCases.profile?.observe else { return }
        profileTask?.cancel()
        profileTask = Task { [weak self] in
            for await state in await observe.execute() {
                guard !Task.isCancelled, let self else { return }
                let profile = state.profile
                guard self.profile != profile else { continue }
                self.profile = profile
                self.render()
            }
        }
    }

    private func observeConnection() {
        guard let observe = useCases.powerTierVerification?.observeConnection else { return }
        connectionTask?.cancel()
        connectionTask = Task { [weak self] in
            for await connection in await observe.execute() {
                guard !Task.isCancelled else { return }
                self?.connection = connection
                self?.render()
            }
        }
    }

    private func render() {
        let nextViewState = mapper.map(
            settings: settings,
            locationAuthorizationStatus: locationAuthorizationStatus,
            profile: profile,
            connection: connection,
            isVerifying: isVerifyingPowerTier,
            verificationMessage: powerTierVerificationMessage
        )
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }
}
