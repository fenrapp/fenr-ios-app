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
    private var settings = AppSettings()
    private var profile: BikeProfile?
    var selectedMapIndex = 0
    private var didSelectInitialMap = false
    private var didRequestRefresh = false
    private var isStarted = false
    var isRefreshing = false
    private var refreshError: String?
    private var nameError: String?
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
    private var settingsSaveTask: Task<Void, Never>?
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
        settingsSaveTask?.cancel()
        controlTask?.cancel()
    }

    public func start() {
        guard observationTask == nil else { return }
        isStarted = true
        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
    }

    public func stop() {
        isStarted = false
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

    @discardableResult
    public func saveName(_ candidate: String) -> Bool {
        guard let vin = profile?.vin else {
            nameError = String(localized: .powerModeSettingsProfileRequiredError)
            render()
            return false
        }
        do {
            let name = try PowerModeName(candidate)
            guard !isDuplicate(name, vin: vin) else {
                nameError = String(localized: .powerModeSettingsDuplicateNameError)
                render()
                return false
            }
            try settings.setPowerModeName(name, forVIN: vin, mapIndex: selectedMapIndex)
            nameError = nil
            render()
            save(settings)
            return true
        } catch {
            nameError = String(localized: .powerModeSettingsInvalidNameError)
            render()
            return false
        }
    }

    public func resetName() {
        guard let vin = profile?.vin else { return }
        settings.clearPowerModeName(forVIN: vin, mapIndex: selectedMapIndex)
        nameError = nil
        render()
        save(settings)
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
        settings = snapshot.settings
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

    private func isDuplicate(_ candidate: PowerModeName, vin: String) -> Bool {
        settings.powerModeNames(forVIN: vin).contains { mapIndex, name in
            mapIndex != selectedMapIndex && candidate.matchesIgnoringCase(name)
        }
    }

    private func save(_ updatedSettings: AppSettings) {
        let previousSaveTask = settingsSaveTask
        let saveSettings = useCases.saveSettings
        settingsSaveTask = Task {
            await previousSaveTask?.value
            guard !Task.isCancelled else { return }
            await saveSettings.execute(updatedSettings)
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
