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
    var isRefreshing = false
    private var refreshError: String?
    private var nameError: String?
    var preparedBaseMapIndex: Int?
    var preparedTractionMapIndex: Int?
    var attemptedPreparationMapIndex: Int?
    var isPreparingControl = false
    var isApplyingControl = false
    var controlMessage: String?
    var controlError: String?
    private var observationTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var settingsSaveTask: Task<Void, Never>?
    var controlTask: Task<Void, Never>?

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
        observationTask?.cancel()
        observationTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        controlTask?.cancel()
        controlTask = nil
        isRefreshing = false
        didRequestRefresh = false
        preparedBaseMapIndex = nil
        preparedTractionMapIndex = nil
        attemptedPreparationMapIndex = nil
        isPreparingControl = false
        isApplyingControl = false
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
        guard let vin = profile?.vin else {
            nameError = "A bike profile is required to save map names."
            render()
            return
        }
        do {
            let name = try PowerModeName(candidate)
            guard !isDuplicate(name, vin: vin) else {
                nameError = "Use a unique name for each map."
                render()
                return
            }
            try settings.setPowerModeName(name, forVIN: vin, mapIndex: selectedMapIndex)
            nameError = nil
            render()
            save(settings)
        } catch {
            nameError = error.localizedDescription
            render()
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
        guard refreshTask == nil, let refreshPowerModes = useCases.refreshPowerModes else { return }
        didRequestRefresh = true
        isRefreshing = true
        refreshError = nil
        controlError = nil
        controlMessage = nil
        preparedBaseMapIndex = nil
        preparedTractionMapIndex = nil
        attemptedPreparationMapIndex = nil
        render()
        refreshTask = Task { [weak self] in
            do {
                try await refreshPowerModes.execute()
                guard !Task.isCancelled else { return }
                self?.finishRefresh(error: nil)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishRefresh(error: "Unable to read power modes: \(error.localizedDescription)")
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
        if !didSelectInitialMap,
           let activeMapIndex = snapshot.telemetry.mode.powerModeConfigurationIndex {
            selectedMapIndex = activeMapIndex
            didSelectInitialMap = true
        }
        if !isAuthenticated(snapshot.connection.state) {
            resetControlState()
        }
        render()
        if isAuthenticated(snapshot.connection.state), !didRequestRefresh {
            refresh()
        }
        prepareControlIfPossible()
    }

    private func finishRefresh(error: String?) {
        refreshTask = nil
        isRefreshing = false
        refreshError = error
        render()
        prepareControlIfPossible()
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
            isRefreshing: isRefreshing,
            refreshError: refreshError,
            nameError: nameError,
            isPreparingControl: isPreparingControl,
            isApplyingControl: isApplyingControl,
            isBaseControlReady: preparedBaseMapIndex == selectedMapIndex,
            isTractionControlReady: preparedTractionMapIndex == selectedMapIndex,
            controlMessage: controlMessage,
            controlError: controlError
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

}
