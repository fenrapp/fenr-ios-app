import Foundation
import MaintenanceDomain

extension MaintenanceViewModel {
    func loadEntries() {
        loadTask?.cancel()
        loadTask = nil
        loadID = nil
        guard let vin = activeVIN else {
            entries = []
            viewState = .init(status: .bikeUnavailable)
            return
        }
        let operationID = UUID()
        loadID = operationID
        loadErrorMessage = nil
        if hasLoadedEntries {
            render()
        } else {
            viewState = .init(status: .loading, errorMessage: errorMessage)
        }
        let loadEntries = useCases.loadEntries
        loadTask = Task { [weak self] in
            do {
                let loaded = try await loadEntries.execute(vin: vin)
                guard !Task.isCancelled, let self, self.activeVIN == vin, self.loadID == operationID else { return }
                await self.synchronizeDateReminders(loaded, requestingAuthorizationFor: nil)
                guard !Task.isCancelled, self.activeVIN == vin, self.loadID == operationID else { return }
                self.loadTask = nil
                self.loadID = nil
                self.entries = loaded
                self.hasLoadedEntries = true
                self.render()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, self.activeVIN == vin, self.loadID == operationID else { return }
                self.loadTask = nil
                self.loadID = nil
                self.loadErrorMessage = String(localized: .maintenanceReadError)
                self.render()
            }
        }
    }

    func completeConfirmedMutation(
        operationID: UUID,
        vin: String,
        confirmedEntries: [MaintenanceEntry],
        requestingAuthorizationFor entryID: UUID?,
        onSuccess: @escaping @MainActor () -> Void
    ) async {
        if let entryID { pendingReminderAuthorizationIDs.insert(entryID) }
        do {
            let refreshed = try await useCases.loadEntries.execute(vin: vin)
            guard !Task.isCancelled, mutationID == operationID, activeVIN == vin else { return }
            await synchronizeDateReminders(refreshed, requestingAuthorizationFor: entryID)
            guard !Task.isCancelled, mutationID == operationID, activeVIN == vin else { return }
            hasLoadedEntries = true
            loadErrorMessage = nil
            finishMutation(operationID: operationID, entries: refreshed, vin: vin)
            onSuccess()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, mutationID == operationID, activeVIN == vin else { return }
            hasLoadedEntries = true
            loadErrorMessage = String(localized: .maintenanceSavedRefreshError)
            finishMutation(operationID: operationID, entries: confirmedEntries, vin: vin)
            onSuccess()
        }
    }

}
