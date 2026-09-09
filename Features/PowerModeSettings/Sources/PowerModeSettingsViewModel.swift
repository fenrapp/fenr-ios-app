import Foundation
import Observation

@MainActor
@Observable
public final class PowerModeSettingsViewModel {
    private let context: PowerModeContext
    private let session: PowerModeSessionCoordinator
    private let traction: PowerModeTractionControls
    private let controls: PowerModeBasicControls
    private let operations: PowerModeOperationController
    private let names: PowerModeNameCoordinator
    private let store: PowerModeDraftStore
    private let mapper: PowerModeSettingsViewStateMapper
    private let summaryMapper: PowerModeBasicSummaryMapper
    public let hasAdvancedEditor: Bool

    init(
        context: PowerModeContext, session: PowerModeSessionCoordinator, controls: PowerModeBasicControls,
        traction: PowerModeTractionControls,
        operations: PowerModeOperationController, names: PowerModeNameCoordinator, store: PowerModeDraftStore,
        mapper: PowerModeSettingsViewStateMapper, summaryMapper: PowerModeBasicSummaryMapper, hasAdvancedEditor: Bool
    ) {
        self.context = context
        self.session = session
        self.traction = traction
        self.controls = controls
        self.operations = operations
        self.names = names
        self.store = store
        self.mapper = mapper
        self.summaryMapper = summaryMapper
        self.hasAdvancedEditor = hasAdvancedEditor
    }

    public var hasAdvancedDraft: Bool { store.drafts[context.selectedMap]?.hasChanges == true }

    public var viewState: PowerModeSettingsViewState {
        mapper.map(.init(
            telemetry: summaryMapper.basicTelemetry(
                context.telemetry, configurations: store.configurations, drafts: store.drafts
            ),
            connection: context.connection, settings: names.settings, profile: context.profile,
            selectedMapIndex: context.selectedMap, isStarted: context.isStarted,
            isRefreshing: operations.active == .refresh, refreshError: controls.refreshError,
            nameError: names.nameError, isSavingName: names.isSaving, nameSaveCompletionID: names.nameSaveCompletionID,
            isPreparingControl: operations.active == .preparation,
            isApplyingControl: operations.isWriting || operations.active == .advancedRead,
            activeAdjustmentID: traction.activeAdjustment
                ?? controls.activeAdjustment,
            pendingAdjustmentValue: controls.pendingValue,
            recentAdjustmentResult: traction.results[context.selectedMap] ?? controls.recentResult,
            isBaseControlReady: controls.preparedBaseMap == context.selectedMap,
            isTractionControlReady: traction.compatibility == .compatible,
            isTractionFirmwareIncompatible: traction.compatibility == .incompatible,
            tractionPower: traction.value(.powerTraction, map: context.selectedMap),
            tractionBraking: traction.value(.brakingTraction, map: context.selectedMap),
            allowsTractionRecommit: traction.allowsUnchangedCommit,
            isTractionBusy: operations.isBusy,
            controlMessage: controls.controlMessage, controlError: controls.controlError,
            isCanonicalTelemetryAvailable: context.isCanonical
        ))
    }

    public func start() { session.start() }
    public func stop() { _ = session.stop() }
    public func stopAndWait() async { await session.stopAndWait() }
    public func setPresentationActive(_ active: Bool) { session.setPresentationActive(active) }
    public func selectMap(index: Int) { session.selectMap(index) }
    public func refresh() {
        traction.retryCompatibility()
        controls.refresh()
    }
    public func saveName(_ candidate: String) { names.saveName(candidate) }
    public func resetName() { names.resetName() }

    public func updateAdjustment(id: PowerModeAdjustmentID, value: Double) {
        guard let adjustment = viewState.adjustments.first(where: { $0.id == id }), adjustment.isEnabled,
              value.isFinite, adjustment.minimum ... adjustment.maximum ~= value,
              adjustment.step.isFinite, adjustment.step > 0 else { return }
        let steps = (value - adjustment.minimum) / adjustment.step
        guard steps.rounded() == steps else { return }
        if id == .powerTraction || id == .brakingTraction {
            controls.clearFeedback()
            traction.apply(id, value: value)
        } else {
            traction.clearFeedback()
            controls.apply(id: id, value: value)
        }
    }
}
