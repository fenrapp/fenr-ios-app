import BikeDomain
import Combine
import EnvironmentDomain
import Foundation
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
    private var powerTierVerificationMessage: LocalizedStringResource?
    private var powerTierVerificationMessageIsError = false
    private var observationTask: Task<Void, Never>?
    private var settingsSaveTask: Task<Void, Never>?
    private var locationAuthorizationTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var profileSaveTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var powerTierTask: Task<Void, Never>?
    private var activePresentationCount = 0

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
        activePresentationCount += 1
        guard activePresentationCount == 1 else { return }
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
        guard activePresentationCount > 0 else { return }
        activePresentationCount -= 1
        guard activePresentationCount == 0 else { return }
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
        render()
        save(updated)
    }

    public func selectDashboardProgressBarMode(id: String) {
        guard let mode = DashboardProgressBarMode(rawValue: id) else { return }
        var updated = settings
        updated.dashboardProgressBarMode = mode
        settings = updated
        render()
        save(updated)
    }

    public func selectDashboardBatteryIndicatorMode(id: String) {
        guard let mode = DashboardBatteryIndicatorMode(rawValue: id) else { return }
        var updated = settings
        updated.dashboardBatteryIndicatorMode = mode
        settings = updated
        render()
        save(updated)
    }

    public func selectDashboardDeviceBatteryDisplayMode(id: String) {
        guard let mode = DashboardDeviceBatteryDisplayMode(rawValue: id) else { return }
        var updated = settings
        updated.dashboardDeviceBatteryDisplayMode = mode
        settings = updated
        render()
        save(updated)
    }

    public func selectDashboardTemperatureDisplayMode(id: String) {
        guard let mode = DashboardTemperatureDisplayMode(rawValue: id) else { return }
        var updated = settings
        updated.dashboardTemperatureDisplayMode = mode
        settings = updated
        render()
        save(updated)
    }

    public func selectMeasurementSystem(id: String) {
        guard let measurementSystem = MeasurementSystem(rawValue: id) else { return }
        var updated = settings
        updated.measurementSystem = measurementSystem
        settings = updated
        render()
        save(updated)
    }

    public func selectBatteryPackCapacity(id: String) {
        guard let batteryPackCapacity = BatteryPackCapacity(rawValue: id), let vin = profile?.vin else { return }
        var updated = settings
        updated.setBatteryPackCapacity(batteryPackCapacity, forVIN: vin)
        settings = updated
        render()
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
        powerTierVerificationMessageIsError = false
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
        powerTierVerificationMessageIsError = false
        render()
        powerTierTask?.cancel()
        powerTierTask = Task { [weak self] in
            do {
                try await refresh.execute()
                try Task.checkCancellation()
                guard let self else { return }
                self.isVerifyingPowerTier = false
                self.powerTierVerificationMessage = .appSettingsVerificationCompleted
                self.powerTierVerificationMessageIsError = false
                self.render()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.isVerifyingPowerTier = false
                self.powerTierVerificationMessage = .appSettingsVerificationFailed
                self.powerTierVerificationMessageIsError = true
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
        let previousSaveTask = settingsSaveTask
        let saveSettings = useCases.settings.save
        settingsSaveTask = Task {
            await previousSaveTask?.value
            guard !Task.isCancelled else { return }
            await saveSettings.execute(settings)
        }
    }

    func updateNavigationSettings(
        _ update: (inout RideNavigationSettings) -> Void
    ) {
        var updated = settings
        update(&updated.rideNavigation)
        guard updated != settings else { return }
        settings = updated
        render()
        save(updated)
    }

    func updateLiveActivitySettings(_ update: (inout LiveActivitySettings) -> Void) {
        var updated = settings
        update(&updated.liveActivities)
        guard updated != settings else { return }
        settings = updated
        render()
        save(updated)
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
            verificationMessage: powerTierVerificationMessage,
            verificationMessageIsError: powerTierVerificationMessageIsError
        )
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }
}

extension AppSettingsViewModel {
    public func stopAndWait() async {
        let tasks = [
            observationTask, settingsSaveTask, locationAuthorizationTask,
            profileTask, profileSaveTask, connectionTask, powerTierTask
        ]
        tasks.forEach { $0?.cancel() }
        stop()
        for task in tasks { await task?.value }
    }

}
