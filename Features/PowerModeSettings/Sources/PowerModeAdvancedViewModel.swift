import Foundation
import Observation

@MainActor
@Observable
public final class PowerModeAdvancedViewModel {
    private let context: PowerModeContext
    private let session: PowerModeSessionCoordinator
    private let store: PowerModeDraftStore
    private let operations: PowerModeOperationController
    private let advanced: PowerModeAdvancedOperations
    private let presets: PowerModePresetCoordinator
    private let names: PowerModeNameCoordinator
    private let mapper: PowerModeAdvancedViewStateMapper
    private let mapMapper: PowerModeMapSelectionMapper
    private var kind: PowerModeCurveKind = .power

    init(
        context: PowerModeContext, session: PowerModeSessionCoordinator, store: PowerModeDraftStore,
        operations: PowerModeOperationController, advanced: PowerModeAdvancedOperations,
        presets: PowerModePresetCoordinator, names: PowerModeNameCoordinator,
        mapper: PowerModeAdvancedViewStateMapper, mapMapper: PowerModeMapSelectionMapper
    ) {
        self.context = context
        self.session = session
        self.store = store
        self.operations = operations
        self.advanced = advanced
        self.presets = presets
        self.names = names
        self.mapper = mapper
        self.mapMapper = mapMapper
    }

    public var maps: [PowerModeMapViewData] {
        mapMapper.map(settings: names.settings, profile: context.profile, selected: context.selectedMap)
    }

    public var viewState: PowerModeAdvancedViewState {
        mapper.map(.init(
            draft: store.drafts[context.selectedMap], kind: kind, maximum: context.maximumHorsepower,
            canEdit: context.canUseConfiguration && store.configurations[context.selectedMap] != nil,
            isBusy: operations.isBusy || presets.isBusy,
            message: advanced.message ?? presets.message, presets: presets.values, presetsLoaded: presets.isLoaded,
            isBaselineCurrent: store.drafts[context.selectedMap]?.baseline == store.configurations[context.selectedMap]
        ))
    }

    public func setVisible(_ visible: Bool) { session.setAdvancedVisible(visible) }

    public func handle(_ intent: PowerModeAdvancedIntent) {
        switch intent {
        case .selectMap(let index): session.selectMap(index)
        case .selectCurve(let selected): kind = selected
        case .refresh: advanced.read()
        case .setPoint(let index, let value): updatePoint(index, value: value)
        case .setTraction(let id, let value): updateTraction(id, value: value)
        case .apply: apply()
        case .discard: discard()
        case .savePreset(let name): savePreset(name)
        case .loadPreset(let id): loadPreset(id)
        case .renamePreset(let id, let name):
            guard !operations.isBusy, !presets.isBusy else { return }
            advanced.clearMessage()
            presets.rename(id, name: name)
        case .duplicatePreset(let id):
            guard !operations.isBusy, !presets.isBusy else { return }
            advanced.clearMessage()
            presets.duplicate(id)
        case .deletePreset(let id):
            guard !operations.isBusy, !presets.isBusy else { return }
            advanced.clearMessage()
            presets.delete(id)
        }
    }

    private func updateTraction(_ id: PowerModeAdjustmentID, value: Double) {
        guard viewState.canEdit else { return }
        store.updateTraction(map: context.selectedMap, id: id, value: value)
        advanced.clearMessage()
        presets.clearMessage()
    }

    private func apply() {
        guard viewState.canApply else { return }
        presets.clearMessage()
        advanced.apply()
    }

    private func discard() {
        guard !operations.isBusy, !presets.isBusy else { return }
        store.discard(context.selectedMap, maximum: context.maximumHorsepower)
        advanced.clearMessage()
        presets.clearMessage()
    }

    private func savePreset(_ name: String) {
        guard viewState.canSavePreset, let draft = store.drafts[context.selectedMap] else { return }
        advanced.clearMessage()
        presets.save(name: name, configuration: draft.configuration, maximum: context.maximumHorsepower)
    }

    private func updatePoint(_ index: Int, value: Double) {
        guard viewState.canEdit else { return }
        do {
            try store.updatePoint(map: context.selectedMap, kind: kind, index: index, value: value,
                                  maximum: context.maximumHorsepower)
            advanced.clearMessage()
            presets.clearMessage()
        } catch { advanced.report(String(localized: .powerCurveInvalidValues)) }
    }

    private func loadPreset(_ id: UUID) {
        guard viewState.canEdit, let preset = presets.values.first(where: { $0.id == id }) else { return }
        if store.load(preset, map: context.selectedMap, maximum: context.maximumHorsepower) {
            advanced.clearMessage()
            presets.clearMessage()
        } else { advanced.report(String(localized: .powerCurveIncompatiblePreset)) }
    }
}
