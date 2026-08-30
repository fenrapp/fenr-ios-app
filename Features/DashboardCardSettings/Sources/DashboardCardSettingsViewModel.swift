import BikeDomain
import Combine
import SettingsDomain

@MainActor
public final class DashboardCardSettingsViewModel: ObservableObject {
    @Published public private(set) var viewState: DashboardCardSettingsViewState

    private let useCases: DashboardCardSettingsUseCases
    private let mapper: DashboardCardSettingsViewStateMapper
    private let bikeLockCapabilityStore: any BikeLockCapabilityStateStoring
    private var settings = AppSettings()
    private var bikeLockCapability = BikeLockCapabilityState()
    private var observationTask: Task<Void, Never>?
    private var bikeLockCapabilityTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var observationRequestCount = 0
    private var pendingConfigurations: [DashboardCardConfiguration] = []
    private var unconfirmedLocalConfiguration: DashboardCardConfiguration?

    public init(
        useCases: DashboardCardSettingsUseCases,
        mapper: DashboardCardSettingsViewStateMapper,
        bikeLockCapabilityStore: any BikeLockCapabilityStateStoring
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.bikeLockCapabilityStore = bikeLockCapabilityStore
        bikeLockCapability = bikeLockCapabilityStore.currentState
        viewState = mapper.map(
            settings: settings,
            bikeLockCapability: bikeLockCapability
        )
    }

    deinit {
        observationTask?.cancel()
        bikeLockCapabilityTask?.cancel()
        saveTask?.cancel()
    }

    public func start() {
        observationRequestCount += 1
        guard observationTask == nil else { return }
        let loadSettings = useCases.loadSettings
        let observeSettings = useCases.observeSettings
        observationTask = Task { [weak self] in
            for await _ in await observeSettings.execute() {
                guard !Task.isCancelled, let self else { return }
                let latestSettings = await loadSettings.execute()
                guard !Task.isCancelled else { return }
                self.receive(latestSettings)
            }
        }
        let bikeLockCapabilityStore = self.bikeLockCapabilityStore
        bikeLockCapabilityTask = Task { [weak self] in
            for await state in bikeLockCapabilityStore.observe() {
                guard !Task.isCancelled, let self else { return }
                guard bikeLockCapability != state else { continue }
                bikeLockCapability = state
                render()
            }
        }
    }

    public func stop() {
        guard observationRequestCount > 0 else { return }
        observationRequestCount -= 1
        guard observationRequestCount == 0 else { return }
        observationTask?.cancel()
        observationTask = nil
        bikeLockCapabilityTask?.cancel()
        bikeLockCapabilityTask = nil
    }

    public func setSectionOrder(ids: [String]) {
        var ids = ids.compactMap(DashboardCardSectionID.init(rawValue:))
        var configuration = settings.dashboardCardConfiguration
        if !ids.contains(.bikeLock),
           let bikeLockIndex = configuration.sections.firstIndex(where: { $0.id == .bikeLock }) {
            ids.insert(.bikeLock, at: min(bikeLockIndex, ids.endIndex))
        }
        configuration.setSectionOrder(ids)
        update(configuration)
    }

    public func setSectionVisibility(_ isVisible: Bool, id: String) {
        guard let id = DashboardCardSectionID(rawValue: id) else { return }
        if id == .bikeLock {
            guard bikeLockCapability.isAvailable,
                  !settings.bikeLockSettings(
                      forVIN: bikeLockCapability.vehicleIdentifier
                  ).securityMode.requiresPIN
            else { return }
        }
        var configuration = settings.dashboardCardConfiguration
        configuration.setSectionVisibility(isVisible, id: id)
        update(configuration)
    }

    public func setPageOrder(ids: [String], sectionID: String) {
        guard let sectionID = DashboardCardSectionID(rawValue: sectionID) else { return }
        let ids = ids.compactMap(DashboardCardPageID.init(rawValue:))
        var configuration = settings.dashboardCardConfiguration
        configuration.setPageOrder(ids, sectionID: sectionID)
        update(configuration)
    }

    public func setPageVisibility(_ isVisible: Bool, id: String, sectionID: String) {
        guard let id = DashboardCardPageID(rawValue: id),
              let sectionID = DashboardCardSectionID(rawValue: sectionID) else { return }
        var configuration = settings.dashboardCardConfiguration
        guard configuration.setPageVisibility(
            isVisible,
            id: id,
            sectionID: sectionID
        ) else { return }
        update(configuration)
    }

    private func receive(_ observedSettings: AppSettings) {
        var updated = observedSettings
        if let unconfirmedLocalConfiguration {
            if observedSettings.dashboardCardConfiguration == unconfirmedLocalConfiguration {
                self.unconfirmedLocalConfiguration = nil
            } else {
                updated.dashboardCardConfiguration = unconfirmedLocalConfiguration
            }
        }
        guard updated != settings else { return }
        settings = updated
        render()
    }

    private func update(_ configuration: DashboardCardConfiguration) {
        guard configuration != settings.dashboardCardConfiguration else { return }
        settings.dashboardCardConfiguration = configuration
        unconfirmedLocalConfiguration = configuration
        pendingConfigurations.append(configuration)
        render()
        startSaveWorkerIfNeeded()
    }

    private func startSaveWorkerIfNeeded() {
        guard saveTask == nil else { return }
        let loadSettings = useCases.loadSettings
        let saveSettings = useCases.saveSettings
        saveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let configuration = self?.nextPendingConfiguration() else { break }
                var latestSettings = await loadSettings.execute()
                guard !Task.isCancelled else { return }
                latestSettings.dashboardCardConfiguration = configuration
                await saveSettings.execute(latestSettings)
                guard !Task.isCancelled else { return }
                self?.didSave(latestSettings)
            }
            guard !Task.isCancelled else { return }
            self?.saveTask = nil
        }
    }

    private func nextPendingConfiguration() -> DashboardCardConfiguration? {
        guard !pendingConfigurations.isEmpty else { return nil }
        return pendingConfigurations.removeFirst()
    }

    private func didSave(_ savedSettings: AppSettings) {
        var updated = savedSettings
        if let unconfirmedLocalConfiguration {
            if pendingConfigurations.isEmpty,
               savedSettings.dashboardCardConfiguration == unconfirmedLocalConfiguration {
                self.unconfirmedLocalConfiguration = nil
            } else {
                updated.dashboardCardConfiguration = unconfirmedLocalConfiguration
            }
        }
        guard updated != settings else { return }
        settings = updated
        render()
    }

    private func render() {
        let next = mapper.map(
            settings: settings,
            bikeLockCapability: bikeLockCapability
        )
        guard next != viewState else { return }
        viewState = next
    }
}
