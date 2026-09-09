import BikeDomain
import Foundation
import Observation

@MainActor
@Observable
final class PowerModeAdvancedOperations {
    private let context: PowerModeContext
    private let operations: PowerModeOperationController
    private let store: PowerModeDraftStore
    private let presets: PowerModePresetCoordinator
    private let useCases: PowerModeAdvancedUseCases
    private(set) var message: String?
    var isAvailable: Bool { useCases.editing != nil }

    init(
        context: PowerModeContext, operations: PowerModeOperationController,
        store: PowerModeDraftStore, presets: PowerModePresetCoordinator, useCases: PowerModeAdvancedUseCases
    ) {
        self.context = context
        self.operations = operations
        self.store = store
        self.presets = presets
        self.useCases = useCases
    }

    func clearMessage() { message = nil }
    func report(_ text: String) { message = text }

    func refreshIfNeeded() {
        if context.isAdvancedVisible || store.configurations[context.selectedMap] != nil { read() }
    }

    func read() {
        guard let editing = useCases.editing, !operations.isBusy, !presets.isBusy,
              context.canUseConfiguration else { return }
        let map = context.selectedMap
        let maximum = context.maximumHorsepower
        let vin = context.profile?.vin
        message = nil
        operations.run(.advancedRead, execute: {
            try await editing.read(mapIndex: map)
        }, completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let configuration):
                self.store.accept(configuration, maximum: maximum)
                if let vin { self.presets.load(vin: vin, force: true) }
            case .failure:
                self.store.invalidate(map)
                self.message = String(localized: .powerCurveReadError)
            }
        })
    }

    func apply() {
        guard let editing = useCases.editing, !operations.isBusy, !presets.isBusy, context.canUseConfiguration,
              let draft = store.drafts[context.selectedMap], draft.hasChanges,
              draft.baseline == store.configurations[context.selectedMap] else { return }
        let maximum = context.maximumHorsepower
        message = nil
        operations.run(.advancedWrite, execute: {
            do {
                let value = try await editing.apply(
                    expected: draft.baseline, desired: draft.configuration, maximumHorsepower: maximum
                )
                return PowerModeCurveWriteResult(configuration: value, succeeded: true)
            } catch {
                try Task.checkCancellation()
                let actual = try? await editing.read(mapIndex: draft.baseline.mapIndex)
                try Task.checkCancellation()
                return PowerModeCurveWriteResult(configuration: actual, succeeded: false)
            }
        }, completion: { [weak self] result in
            guard let self else { return }
            if case .success(let outcome) = result {
                if let value = outcome.configuration {
                    self.store.accept(value, maximum: maximum, replaceDraft: outcome.succeeded)
                } else { self.store.invalidate(draft.baseline.mapIndex) }
                self.message = String(localized: outcome.succeeded ? .powerCurveConfirmed : .powerCurveApplyError)
            } else {
                self.store.invalidate(draft.baseline.mapIndex)
                self.message = String(localized: .powerCurveApplyError)
            }
        })
    }
}
