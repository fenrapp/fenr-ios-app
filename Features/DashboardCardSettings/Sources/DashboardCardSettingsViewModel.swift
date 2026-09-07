import BikeDomain
import Combine
import Foundation
import SettingsDomain

@MainActor
public final class DashboardCardSettingsViewModel: ObservableObject {
    @Published public private(set) var viewState: DashboardCardSettingsViewState
    @Published public private(set) var settingsSaveError: String?

    private let useCases: DashboardCardSettingsUseCases
    private let mapper: DashboardCardSettingsViewStateMapper
    private let bikeLockCapabilityStore: any BikeLockCapabilityStateStoring
    private var settings = AppSettings()
    private var bikeLockCapability = BikeLockCapabilityState()
    private var observationTask: Task<Void, Never>?
    private var bikeLockCapabilityTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var observationRequestCount = 0
    private(set) var pendingSettings = AppSettingsPendingChanges()

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
        let observeSettings = useCases.observeSettings
        observationTask = Task { [weak self] in
            for await snapshot in await observeSettings.execute() {
                guard !Task.isCancelled, let self else { return }
                self.receive(snapshot)
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

    public func stopAndWait() async {
        let tasks = [
            observationTask, bikeLockCapabilityTask, saveTask
        ]
        tasks.forEach { $0?.cancel() }
        pendingSettings.removeAll()
        settings = pendingSettings.settings
        stop()
        for task in tasks { await task?.value }
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
        update(.sectionOrder(ids.compactMap(DashboardCardSectionID.init(rawValue:))))
    }

    public func setSectionVisibility(_ isVisible: Bool, id: String) {
        guard let id = DashboardCardSectionID(rawValue: id), id != .bikeLock, id != .settings else { return }
        update(.sectionVisibility(id: id, isVisible: isVisible))
    }

    public func setPageOrder(ids: [String], sectionID: String) {
        guard let sectionID = DashboardCardSectionID(rawValue: sectionID) else { return }
        update(.pageOrder(sectionID: sectionID, ids: ids.compactMap(DashboardCardPageID.init(rawValue:))))
    }

    public func setPageVisibility(_ isVisible: Bool, id: String, sectionID: String) {
        guard let id = DashboardCardPageID(rawValue: id),
              let sectionID = DashboardCardSectionID(rawValue: sectionID) else { return }
        var configuration = settings.dashboardCardConfiguration
        guard configuration.setPageVisibility(isVisible, id: id, sectionID: sectionID) else { return }
        update(.pageVisibility(sectionID: sectionID, id: id, isVisible: isVisible))
    }

    public func dismissSettingsSaveError() {
        settingsSaveError = nil
    }

    private func receive(_ snapshot: AppSettingsSnapshot) {
        pendingSettings.receive(snapshot)
        settings = pendingSettings.settings
        render()
    }

    private func update(_ change: AppSettingsChange.Dashboard) {
        do {
            let change = AppSettingsChange.dashboard(change)
            guard try change.applying(to: settings) != settings else { return }
            try pendingSettings.enqueue(change)
            settings = pendingSettings.settings
            render()
            startSaveWorkerIfNeeded()
        } catch {
            settingsSaveError = String(localized: .dashboardCardSettingsSaveFailed)
        }
    }

    private func startSaveWorkerIfNeeded() {
        guard saveTask == nil else { return }
        let update = useCases.updateSettings
        saveTask = Task { [weak self] in
            defer { self?.saveTask = nil }
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
                        settingsSaveError = String(localized: .dashboardCardSettingsSaveFailed)
                    }
                    settings = pendingSettings.settings
                    render()
                }
            }
        }
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
