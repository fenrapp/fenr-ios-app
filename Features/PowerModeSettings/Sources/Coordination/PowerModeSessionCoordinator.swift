import Foundation
import VehicleSession

@MainActor
final class PowerModeSessionCoordinator {
    private let vehicleSession: any VehicleSessionService
    private let context: PowerModeContext
    private let operations: PowerModeOperationController
    private let names: PowerModeNameCoordinator
    private let controls: PowerModeBasicControls
    private let advanced: PowerModeAdvancedOperations
    private let store: PowerModeDraftStore
    private let presets: PowerModePresetCoordinator
    private var observationTask: Task<Void, Never>?
    private var generation = 0

    init(
        vehicleSession: any VehicleSessionService, context: PowerModeContext,
        operations: PowerModeOperationController, names: PowerModeNameCoordinator,
        controls: PowerModeBasicControls, advanced: PowerModeAdvancedOperations,
        store: PowerModeDraftStore, presets: PowerModePresetCoordinator
    ) {
        self.vehicleSession = vehicleSession
        self.context = context
        self.operations = operations
        self.names = names
        self.controls = controls
        self.advanced = advanced
        self.store = store
        self.presets = presets
    }

    deinit { observationTask?.cancel() }

    func start() {
        guard observationTask == nil else { return }
        context.isStarted = true
        names.observeSettingsIfNeeded()
        generation += 1
        let token = generation
        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled, let self, token == self.generation else { return }
                self.receive(snapshot)
            }
        }
    }

    func setPresentationActive(_ active: Bool) {
        if active { start() } else {
            generation += 1
            observationTask?.cancel()
            observationTask = nil
        }
    }

    func setAdvancedVisible(_ visible: Bool) {
        context.isAdvancedVisible = visible
        if visible {
            start()
            advanced.read()
        }
    }

    func selectMap(_ index: Int) {
        guard 0 ... 4 ~= index, context.selectedMap != index, !operations.isWriting,
              operations.active != .advancedRead, !presets.isBusy else { return }
        let wasRefreshing = operations.active == .refresh
        operations.cancel()
        context.select(index)
        controls.reset(resetRefresh: wasRefreshing)
        names.clearError()
        advanced.clearMessage()
        controls.receive()
        if context.isAdvancedVisible { advanced.read() }
    }

    func stop() -> [Task<Void, Never>] {
        generation += 1
        context.isStarted = false
        context.isAdvancedVisible = false
        let tasks = [observationTask, operations.cancel(), presets.cancel(clear: false)].compactMap { $0 }
        observationTask?.cancel()
        observationTask = nil
        controls.reset(resetRefresh: true)
        return tasks + names.stop()
    }

    func stopAndWait() async {
        let tasks = stop()
        for task in tasks { await task.value }
    }

    private func receive(_ snapshot: VehicleSessionSnapshot) {
        let changedBike = context.profile?.vin != snapshot.profile?.vin
        let wasReady = context.canUseConfiguration
        let wasAuthenticated = context.isAuthenticated
        context.receive(snapshot)
        if changedBike {
            operations.cancel()
            presets.cancel(clear: true)
            store.clear()
            controls.reset(resetRefresh: true)
            advanced.clearMessage()
            names.clearError()
        }
        if !context.canUseConfiguration {
            if wasReady || (wasAuthenticated && !context.isAuthenticated) {
                operations.cancel()
                presets.cancel(clear: false)
                controls.reset(resetRefresh: true)
            }
            store.invalidate()
        }
        controls.receive()
        if context.isAdvancedVisible, !wasReady, context.canUseConfiguration, !operations.isBusy {
            advanced.read()
        }
    }
}
