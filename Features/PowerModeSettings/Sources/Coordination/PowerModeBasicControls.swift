import BikeDomain
import Foundation
import Observation

@MainActor
@Observable
final class PowerModeBasicControls {
    private let context: PowerModeContext
    private let operations: PowerModeOperationController
    private let advanced: PowerModeAdvancedOperations
    private let store: PowerModeDraftStore
    private let useCases: PowerModeSettingsUseCases
    private let writer: PowerModeBasicWriter
    private let preparation: PowerModeControlPreparation
    private(set) var didRequestRefresh = false
    private(set) var refreshError: String?
    private(set) var controlError: String?
    private(set) var controlMessage: String?
    private(set) var preparedBaseMap: Int?
    private(set) var preparedTractionMap: Int?
    private(set) var activeAdjustment: PowerModeAdjustmentID?
    private(set) var recentResult: PowerModeAdjustmentResult?
    private var attemptedMap: Int?

    init(
        context: PowerModeContext, operations: PowerModeOperationController, advanced: PowerModeAdvancedOperations,
        store: PowerModeDraftStore, useCases: PowerModeSettingsUseCases,
        writer: PowerModeBasicWriter, preparation: PowerModeControlPreparation
    ) {
        self.context = context
        self.operations = operations
        self.advanced = advanced
        self.store = store
        self.useCases = useCases
        self.writer = writer
        self.preparation = preparation
    }

    func receive() {
        guard context.isAuthenticated else { return }
        if !didRequestRefresh { refresh() } else { prepare() }
    }

    func reset(resetRefresh: Bool = false) {
        preparedBaseMap = nil
        preparedTractionMap = nil
        attemptedMap = nil
        activeAdjustment = nil
        recentResult = nil
        controlError = nil
        controlMessage = nil
        if resetRefresh {
            didRequestRefresh = false
            refreshError = nil
        }
    }

    func refresh() {
        guard context.isStarted, context.isAuthenticated, !operations.isBusy else { return }
        didRequestRefresh = true
        refreshError = nil
        reset()
        let refresh = useCases.refreshPowerModes
        operations.run(.refresh, execute: { try await refresh.execute() }, completion: { [weak self] result in
            guard let self else { return }
            if case .failure = result { self.refreshError = String(localized: .powerModeSettingsReadError) }
            self.prepare()
            self.advanced.refreshIfNeeded()
        })
    }

    func prepare() {
        guard context.canUseConfiguration, !operations.isBusy else { return }
        let map = context.selectedMap
        let configuration = context.telemetry.powerModeConfigurations[map]
        if advanced.isAvailable {
            preparedBaseMap = configuration?.hasBaseConfiguration == true ? map : nil
            preparedTractionMap = configuration?.hasTractionControlConfiguration == true ? map : nil
            return
        }
        guard preparedBaseMap != map, attemptedMap != map, configuration?.hasBaseConfiguration == true else { return }
        attemptedMap = map
        controlError = nil
        controlMessage = nil
        let preparation = preparation
        let tractionAvailable = configuration?.hasTractionControlConfiguration == true
        operations.run(.preparation, execute: {
            try await preparation.execute(map: map, tractionAvailable: tractionAvailable)
        }, completion: { [weak self] result in
            guard let self else { return }
            if case .success(let readiness) = result {
                self.preparedBaseMap = readiness.baseReady ? map : nil
                self.preparedTractionMap = readiness.tractionReady ? map : nil
                self.controlError = readiness.error
                if readiness.error == nil {
                    self.controlMessage = String(localized:
                        readiness.tractionReady
                            ? .powerModeSettingsAllControlsReady : .powerModeSettingsBaseControlsReady
                    )
                }
            }
        })
    }

    func apply(id: PowerModeAdjustmentID, value: Double) {
        guard context.canUseConfiguration, !operations.isBusy else { return }
        let map = context.selectedMap
        let isBase = id == .power || id == .regeneration
        guard (isBase ? preparedBaseMap : preparedTractionMap) == map else { return }
        activeAdjustment = id
        recentResult = nil
        controlError = nil
        controlMessage = nil
        let writer = writer
        let maximum = context.maximumHorsepower
        let configuration = context.telemetry.powerModeConfigurations[map]
        operations.run(.basicWrite, execute: {
            try await writer.execute(map: map, id: id, value: value, maximum: maximum, configuration: configuration)
        }, completion: { [weak self] result in
            guard let self else { return }
            self.activeAdjustment = nil
            switch result {
            case .success(let outcome): self.accept(outcome, map: map, id: id, maximum: maximum)
            case .failure:
                self.fail(map: map, id: id, message: String(localized: .powerCurveApplyError))
            }
        })
    }

    private func accept(_ result: PowerModeBasicWriteResult, map: Int, id: PowerModeAdjustmentID, maximum: Int) {
        if let value = result.advanced {
            if result.error == nil {
                store.acceptBasic(value, adjustment: id, maximum: maximum)
            } else { store.accept(value, maximum: maximum) }
        } else if advanced.isAvailable { store.invalidate(map) }
        if let error = result.error {
            fail(map: map, id: id, message: error)
            return
        }
        switch result.values {
        case .base(let horsepower, let regeneration):
            context.telemetry.powerModeConfigurations[map]?.horsepower = horsepower
            context.telemetry.powerModeConfigurations[map]?.regenerativeBrakingPercent = Double(regeneration)
        case .traction(let power, let braking):
            context.telemetry.powerModeConfigurations[map]?.powerTractionPercent = power
            context.telemetry.powerModeConfigurations[map]?.brakingTractionPercent = braking
        case nil: break
        }
        recentResult = .confirmed(id)
        controlMessage = String(localized: .powerModeSettingsMapConfirmed(map + 1))
    }

    private func fail(map: Int, id: PowerModeAdjustmentID, message: String) {
        controlError = message
        recentResult = .failed(id, message: message)
        if id == .power || id == .regeneration { preparedBaseMap = nil } else { preparedTractionMap = nil }
        attemptedMap = map
    }
}
