import Foundation
import Observation
import SettingsDomain

@MainActor
@Observable
final class PowerModeNameCoordinator {
    private let context: PowerModeContext
    private let useCases: PowerModeSettingsUseCases
    private(set) var settings = AppSettings()
    private var pendingChanges = AppSettingsPendingChanges()
    private(set) var nameError: String?
    private(set) var nameSaveCompletionID: UUID?
    @ObservationIgnored private var settingsObservationTask: Task<Void, Never>?
    @ObservationIgnored private var settingsSaveTask: Task<Void, Never>?
    @ObservationIgnored private var settingsGeneration = 0
    var isSaving: Bool { !pendingChanges.isEmpty }

    init(context: PowerModeContext, useCases: PowerModeSettingsUseCases) {
        self.context = context
        self.useCases = useCases
    }

    deinit {
        settingsObservationTask?.cancel()
        settingsSaveTask?.cancel()
    }

    func clearError() { nameError = nil }

    func saveName(_ candidate: String) {
        do {
            let name = try PowerModeName(candidate)
            saveNameChange(.powerModeName(mapIndex: context.selectedMap, name: name))
        } catch { nameError = String(localized: .powerModeSettingsInvalidNameError) }
    }

    func resetName() { saveNameChange(.powerModeName(mapIndex: context.selectedMap, name: nil)) }

    func stop() -> [Task<Void, Never>] {
        settingsGeneration += 1
        let tasks = [settingsObservationTask, settingsSaveTask].compactMap { $0 }
        tasks.forEach { $0.cancel() }
        settingsObservationTask = nil
        settingsSaveTask = nil
        pendingChanges.removeAll()
        nameError = nil
        return tasks
    }

    func observeSettingsIfNeeded() {
        guard settingsObservationTask == nil else { return }
        let observeSettings = useCases.observeSettings
        settingsObservationTask = Task { [weak self] in
            let stream = await observeSettings.execute()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receiveSettings(snapshot)
            }
        }
    }

    private func receiveSettings(_ snapshot: AppSettingsSnapshot) {
        let previousVIN = pendingChanges.confirmed?.settings.vin
        pendingChanges.receive(snapshot)
        settings = pendingChanges.confirmed?.settings ?? AppSettings()
        if previousVIN != settings.vin { nameError = nil }
    }

    func saveNameChange(_ change: AppSettingsChange) {
        guard let vin = context.profile?.vin, pendingChanges.confirmed?.settings.vin == vin else {
            nameError = String(localized: .powerModeSettingsProfileRequiredError)
            return
        }
        do {
            try pendingChanges.enqueue(change)
            nameError = nil
            savePendingNameChanges()
        } catch {
            reportNameSaveError(error)
        }
    }

    private func savePendingNameChanges() {
        guard settingsSaveTask == nil else { return }
        let updateSettings = useCases.updateSettings
        let generation = settingsGeneration
        settingsSaveTask = Task { [weak self] in
            while let pending = self?.pendingChanges.next {
                do {
                    let result = try await updateSettings.execute(
                        expectedVIN: pending.expectedVIN, change: pending.change
                    )
                    guard !Task.isCancelled, self?.settingsGeneration == generation else { return }
                    if self?.pendingChanges.complete(id: pending.id, result: result) == true,
                       self?.context.profile?.vin == pending.expectedVIN {
                        self?.nameSaveCompletionID = pending.id
                    }
                    self?.settings = self?.pendingChanges.confirmed?.settings ?? AppSettings()
                } catch {
                    guard !Task.isCancelled, self?.settingsGeneration == generation else { return }
                    if self?.pendingChanges.reject(id: pending.id) == true {
                        self?.reportNameSaveError(error)
                    }
                }
            }
            guard !Task.isCancelled, self?.settingsGeneration == generation else { return }
            self?.settingsSaveTask = nil
        }
    }

    private func reportNameSaveError(_ error: any Error) {
        switch error {
        case AppSettingsUpdateError.duplicatePowerModeName:
            nameError = String(localized: .powerModeSettingsDuplicateNameError)
        case AppSettingsUpdateError.vehicleUnavailable, AppSettingsUpdateError.vehicleChanged:
            nameError = String(localized: .powerModeSettingsProfileRequiredError)
        case AppSettingsUpdateError.invalidChange:
            nameError = String(localized: .powerModeSettingsInvalidNameError)
        default:
            nameError = String(localized: .powerModeSettingsNameSaveError)
        }
    }
}
