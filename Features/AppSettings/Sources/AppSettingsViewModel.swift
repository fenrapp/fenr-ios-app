import BikeDomain
import EnvironmentDomain
import Foundation
import Observation
import SettingsDomain

@MainActor
@Observable
public final class AppSettingsViewModel {
    public private(set) var viewState: AppSettingsViewState
    public private(set) var settingsSaveError: String?

    private let useCases: AppSettingsUseCases
    private let mapper: AppSettingsViewStateMapper
    @ObservationIgnored private var settings = AppSettings()
    @ObservationIgnored private(set) var pendingSettings = AppSettingsPendingChanges()
    @ObservationIgnored private var locationAuthorizationStatus: LocationAuthorizationStatus = .notDetermined
    @ObservationIgnored private var profile: BikeProfile?
    @ObservationIgnored private var connection = BikeConnection()
    @ObservationIgnored private var isVerifyingPowerTier = false
    @ObservationIgnored private var powerTierVerificationMessage: LocalizedStringResource?
    @ObservationIgnored private var powerTierVerificationMessageIsError = false
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var settingsSaveTask: Task<Void, Never>?
    @ObservationIgnored private var locationAuthorizationTask: Task<Void, Never>?
    @ObservationIgnored private var profileTask: Task<Void, Never>?
    @ObservationIgnored private var profileSaveTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var powerTierTask: Task<Void, Never>?
    @ObservationIgnored private var activePresentationCount = 0

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
            for await snapshot in stream {
                guard !Task.isCancelled, let self else { return }
                self.pendingSettings.receive(snapshot)
                self.settings = self.pendingSettings.settings
                self.render()
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
        applyAndSave(.speedSource(speedSource))
    }

    public func selectDashboardProgressBarMode(id: String) {
        guard let mode = DashboardProgressBarMode(rawValue: id) else { return }
        applyAndSave(.dashboardProgressBarMode(mode))
    }

    public func selectDashboardBatteryIndicatorMode(id: String) {
        guard let mode = DashboardBatteryIndicatorMode(rawValue: id) else { return }
        applyAndSave(.dashboardBatteryIndicatorMode(mode))
    }

    public func selectDashboardDeviceBatteryDisplayMode(id: String) {
        guard let mode = DashboardDeviceBatteryDisplayMode(rawValue: id) else { return }
        applyAndSave(.dashboardDeviceBatteryDisplayMode(mode))
    }

    public func selectDashboardTemperatureDisplayMode(id: String) {
        guard let mode = DashboardTemperatureDisplayMode(rawValue: id) else { return }
        applyAndSave(.dashboardTemperatureDisplayMode(mode))
    }

    public func selectMeasurementSystem(id: String) {
        guard let measurementSystem = MeasurementSystem(rawValue: id) else { return }
        applyAndSave(.measurementSystem(measurementSystem))
    }

    public func selectBatteryPackCapacity(id: String) {
        guard let batteryPackCapacity = BatteryPackCapacity(rawValue: id),
              profile?.vin == settings.vin else { return }
        applyAndSave(.batteryPackCapacity(batteryPackCapacity))
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
        let status = await locationAuthorizationStatus.execute()
        guard !Task.isCancelled else { return }
        self.locationAuthorizationStatus = status
        render()
    }

    func applyAndSave(_ change: AppSettingsChange) {
        do {
            guard try change.applying(to: settings) != settings else { return }
            try pendingSettings.enqueue(change)
            settings = pendingSettings.settings
            render()
            startSettingsWorkerIfNeeded()
        } catch {
            settingsSaveError = String(localized: .appSettingsSaveFailed)
        }
    }

    public func dismissSettingsSaveError() {
        settingsSaveError = nil
    }

    private func startSettingsWorkerIfNeeded() {
        guard settingsSaveTask == nil else { return }
        let update = useCases.settings.update
        settingsSaveTask = Task { [weak self] in
            defer { self?.settingsSaveTask = nil }
            while !Task.isCancelled, let pending = self?.pendingSettings.next {
                do {
                    let result = try await update.execute(expectedVIN: pending.expectedVIN, change: pending.change)
                    guard !Task.isCancelled, let self else { return }
                    pendingSettings.complete(id: pending.id, result: result)
                    settings = pendingSettings.settings
                    render()
                } catch {
                    guard !Task.isCancelled, let self else { return }
                    if pendingSettings.reject(id: pending.id) {
                        settingsSaveError = String(localized: .appSettingsSaveFailed)
                    }
                    settings = pendingSettings.settings
                    render()
                }
            }
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
        pendingSettings.removeAll()
        settings = pendingSettings.settings
        stop()
        for task in tasks { await task?.value }
    }

}
