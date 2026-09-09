import Foundation
import Observation

@MainActor
@Observable
public final class PowerModeSettingsViewModel {
    private let context: PowerModeContext
    private let session: PowerModeSessionCoordinator
    private let controls: PowerModeBasicControls
    private let operations: PowerModeOperationController
    private let names: PowerModeNameCoordinator
    private let store: PowerModeDraftStore
    private let mapper: PowerModeSettingsViewStateMapper
    private let summaryMapper: PowerModeBasicSummaryMapper
    public let hasAdvancedEditor: Bool

    init(
        context: PowerModeContext, session: PowerModeSessionCoordinator, controls: PowerModeBasicControls,
        operations: PowerModeOperationController, names: PowerModeNameCoordinator, store: PowerModeDraftStore,
        mapper: PowerModeSettingsViewStateMapper, summaryMapper: PowerModeBasicSummaryMapper, hasAdvancedEditor: Bool
    ) {
        self.context = context
        self.session = session
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
            activeAdjustmentID: controls.activeAdjustment, pendingAdjustmentValue: controls.pendingValue,
            recentAdjustmentResult: controls.recentResult,
            isBaseControlReady: controls.preparedBaseMap == context.selectedMap,
            isTractionControlReady: controls.preparedTractionMap == context.selectedMap,
            controlMessage: controls.controlMessage, controlError: controls.controlError,
            isCanonicalTelemetryAvailable: context.isCanonical
        ))
    }

    public func start() { session.start() }
    public func stop() { _ = session.stop() }
    public func stopAndWait() async { await session.stopAndWait() }
    public func setPresentationActive(_ active: Bool) { session.setPresentationActive(active) }
    public func selectMap(index: Int) { session.selectMap(index) }
    public func refresh() { controls.refresh() }
    public func saveName(_ candidate: String) { names.saveName(candidate) }
    public func resetName() { names.resetName() }

    public func updateAdjustment(id: PowerModeAdjustmentID, value: Double) {
        guard let adjustment = viewState.adjustments.first(where: { $0.id == id }), adjustment.isEnabled,
              value.isFinite, adjustment.minimum ... adjustment.maximum ~= value,
              adjustment.step.isFinite, adjustment.step > 0 else { return }
        let steps = (value - adjustment.minimum) / adjustment.step
        guard steps.rounded() == steps else { return }
        controls.apply(id: id, value: value)
    }
}
