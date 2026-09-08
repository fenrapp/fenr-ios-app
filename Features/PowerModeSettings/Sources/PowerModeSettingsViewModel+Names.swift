import Foundation
import SettingsDomain

extension PowerModeSettingsViewModel {
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
        render()
    }

    func saveNameChange(_ change: AppSettingsChange) {
        guard let vin = profile?.vin, pendingChanges.confirmed?.settings.vin == vin else {
            nameError = String(localized: .powerModeSettingsProfileRequiredError)
            render()
            return
        }
        do {
            try pendingChanges.enqueue(change)
            nameError = nil
            render()
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
                       self?.profile?.vin == pending.expectedVIN {
                        self?.nameSaveCompletionID = pending.id
                    }
                    self?.settings = self?.pendingChanges.confirmed?.settings ?? AppSettings()
                } catch {
                    guard !Task.isCancelled, self?.settingsGeneration == generation else { return }
                    if self?.pendingChanges.reject(id: pending.id) == true {
                        self?.reportNameSaveError(error)
                    }
                }
                self?.render()
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
        render()
    }
}
