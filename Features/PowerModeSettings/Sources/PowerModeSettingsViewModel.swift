import BikeDomain
import Combine
import Foundation
import SettingsDomain
import VehicleSession

@MainActor
public final class PowerModeSettingsViewModel: ObservableObject {
    @Published public private(set) var viewState = PowerModeSettingsViewState()

    private let vehicleSession: any VehicleSessionService
    let useCases: PowerModeSettingsUseCases
    private let mapper: PowerModeSettingsViewStateMapper
    var telemetry = BikeTelemetry()
    var connection = BikeConnection()
    var settings = AppSettings()
    var pendingChanges = AppSettingsPendingChanges()
    var nameSaveCompletionID: UUID?
    var settingsObservationTask: Task<Void, Never>?
    var settingsGeneration = 0
    var profile: BikeProfile?
    var selectedMapIndex = 0
    private var didSelectInitialMap = false
    private var didRequestRefresh = false
    private var isStarted = false
    var isRefreshing = false
    private var refreshError: String?
    var nameError: String?
    var preparedBaseMapIndex: Int?
    var preparedTractionMapIndex: Int?
    var attemptedPreparationMapIndex: Int?
    var isPreparingControl = false
    var isApplyingControl = false
    var activeAdjustmentID: PowerModeAdjustmentID?
    var recentAdjustmentResult: PowerModeAdjustmentResult?
    var controlMessage: String?
    var controlError: String?
    private var observationTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    var settingsSaveTask: Task<Void, Never>?
    var controlTask: Task<Void, Never>?
    private var refreshGeneration = 0
    var controlGeneration = 0
    var isCanonicalTelemetryAvailable = false

    public init(
        vehicleSession: any VehicleSessionService,
        useCases: PowerModeSettingsUseCases,
        mapper: PowerModeSettingsViewStateMapper
    ) {
        self.vehicleSession = vehicleSession
        self.useCases = useCases
        self.mapper = mapper
    }

    deinit {
        observationTask?.cancel()
        refreshTask?.cancel()
        settingsObservationTask?.cancel()
        settingsSaveTask?.cancel()
        controlTask?.cancel()
    }

    public func start() {
        guard observationTask == nil else { return }
        isStarted = true
        observeSettingsIfNeeded()
        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
    }

    public func setPresentationActive(_ isActive: Bool) {
        if isActive {
            start()
        } else {
            observationTask?.cancel()
            observationTask = nil
        }
    }

    public func stopAndWait() async {
        let tasks = [observationTask, refreshTask, settingsObservationTask, settingsSaveTask, controlTask]
        tasks.forEach { $0?.cancel() }
        stop()
        for task in tasks { await task?.value }
    }

    public func stop() {
        isStarted = false
        settingsGeneration += 1
        settingsObservationTask?.cancel()
        settingsObservationTask = nil
        settingsSaveTask?.cancel()
        settingsSaveTask = nil
        pendingChanges.removeAll()
        observationTask?.cancel()
        observationTask = nil
        cancelRefresh(resetRequest: true)
        resetControlState()
        nameError = nil
        render()
    }

    public func selectMap(index: Int) {
        guard 0 ... 4 ~= index, index != selectedMapIndex else { return }
        selectedMapIndex = index
        didSelectInitialMap = true
        resetControlState()
        nameError = nil
        render()
        prepareControlIfPossible()
    }

    public func saveName(_ candidate: String) {
        do {
            let name = try PowerModeName(candidate)
            saveNameChange(.powerModeName(mapIndex: selectedMapIndex, name: name))
        } catch {
            nameError = String(localized: .powerModeSettingsInvalidNameError)
            render()
        }
    }

    public func resetName() {
        saveNameChange(.powerModeName(mapIndex: selectedMapIndex, name: nil))
    }

    public func refresh() {
        guard isStarted,
              refreshTask == nil,
              controlTask == nil,
              isAuthenticated(connection.state)
        else {
            return
        }
        didRequestRefresh = true
        isRefreshing = true
        refreshError = nil
        clearAdjustmentFeedback()
        controlError = nil
        controlMessage = nil
        preparedBaseMapIndex = nil
        preparedTractionMapIndex = nil
        attemptedPreparationMapIndex = nil
        render()
        refreshGeneration += 1
        let generation = refreshGeneration
        let refreshPowerModes = useCases.refreshPowerModes
        refreshTask = Task { [weak self] in
            do {
                try await refreshPowerModes.execute()
                guard !Task.isCancelled else { return }
                self?.finishRefresh(generation: generation, error: nil)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishRefresh(
                    generation: generation,
                    error: String(localized: .powerModeSettingsReadError)
                )
            }
        }
    }
}

extension PowerModeSettingsViewModel {
    private func receive(_ snapshot: VehicleSessionSnapshot) {
        telemetry = snapshot.telemetry
        connection = snapshot.connection
        profile = snapshot.profile
        isCanonicalTelemetryAvailable = snapshot.isCanonicalTelemetryAvailable
        if !didSelectInitialMap,
           let activeMapIndex = snapshot.telemetry.mode.powerModeConfigurationIndex {
            selectedMapIndex = activeMapIndex
            didSelectInitialMap = true
        }
        let isConnected = isAuthenticated(snapshot.connection.state)
        if !isConnected || !isCanonicalTelemetryAvailable {
            cancelRefresh(resetRequest: true)
            resetControlState()
        }
        render()
        if isConnected, !didRequestRefresh {
            refresh()
        }
        prepareControlIfPossible()
    }

    private func finishRefresh(generation: Int, error: String?) {
        guard generation == refreshGeneration else { return }
        refreshTask = nil
        isRefreshing = false
        refreshError = error
        render()
        prepareControlIfPossible()
    }

    private func cancelRefresh(resetRequest: Bool) {
        refreshGeneration += 1
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
        if resetRequest {
            didRequestRefresh = false
        }
    }

    func render() {
        let nextState = mapper.map(.init(
            telemetry: telemetry,
            connection: connection,
            settings: settings,
            profile: profile,
            selectedMapIndex: selectedMapIndex,
            isStarted: isStarted,
            isRefreshing: isRefreshing,
            refreshError: refreshError,
            nameError: nameError,
            isSavingName: !pendingChanges.isEmpty,
            nameSaveCompletionID: nameSaveCompletionID,
            isPreparingControl: isPreparingControl,
            isApplyingControl: isApplyingControl,
            activeAdjustmentID: activeAdjustmentID,
            recentAdjustmentResult: recentAdjustmentResult,
            isBaseControlReady: preparedBaseMapIndex == selectedMapIndex,
            isTractionControlReady: preparedTractionMapIndex == selectedMapIndex,
            controlMessage: controlMessage,
            controlError: controlError,
            isCanonicalTelemetryAvailable: isCanonicalTelemetryAvailable
        ))
        guard nextState != viewState else { return }
        viewState = nextState
    }

    func isAuthenticated(_ state: ConnectionState) -> Bool {
        switch state {
        case .authenticated, .subscribed, .receivingTelemetry: true
        default: false
        }
    }

    func clearAdjustmentFeedback() {
        activeAdjustmentID = nil
        recentAdjustmentResult = nil
    }

}
