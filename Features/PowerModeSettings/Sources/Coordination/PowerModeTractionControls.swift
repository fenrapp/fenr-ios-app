import BikeDomain
import Foundation
import Observation

@MainActor
@Observable
final class PowerModeTractionControls {
    enum Compatibility { case pending, checking, compatible, incompatible, failed }

    private let context: PowerModeContext
    private let operations: PowerModeOperationController
    private let store: PowerModeDraftStore
    private let compatibilityUseCase: ReadBikeTractionCompatibilityUseCase
    private let applyUseCase: ApplyUserBikeTractionControlConfigurationUseCase
    private(set) var compatibility = Compatibility.pending
    private(set) var activeAdjustment: PowerModeAdjustmentID?
    private(set) var results: [Int: PowerModeAdjustmentResult] = [:]
    private(set) var proposals: [Int: [PowerModeAdjustmentID: Double]] = [:]
    private var confirmed: [Int: BikeTractionControlSnapshot] = [:]
    @ObservationIgnored private var compatibilityTask: Task<Void, Never>?
    private var generation = 0

    init(
        context: PowerModeContext, operations: PowerModeOperationController, store: PowerModeDraftStore,
        compatibility: ReadBikeTractionCompatibilityUseCase,
        apply: ApplyUserBikeTractionControlConfigurationUseCase
    ) {
        self.context = context
        self.operations = operations
        self.store = store
        self.compatibilityUseCase = compatibility
        self.applyUseCase = apply
    }

    deinit { compatibilityTask?.cancel() }

    func receive() {
        guard context.isStarted, context.isAuthenticated, compatibility == .pending else { return }
        compatibility = .checking
        let token = generation
        let useCase = compatibilityUseCase
        compatibilityTask = Task { [weak self] in
            let result: Result<BikeTractionControlFirmwareCompatibility, any Error>
            do { result = .success(try await useCase.execute()) } catch { result = .failure(error) }
            guard !Task.isCancelled, let self, self.generation == token else { return }
            self.compatibilityTask = nil
            switch result {
            case .success(let value): self.compatibility = value.isCompatible ? .compatible : .incompatible
            case .failure: self.compatibility = .failed
            }
        }
    }

    @discardableResult
    func reset() -> Task<Void, Never>? {
        generation += 1
        let pending = compatibilityTask
        pending?.cancel()
        compatibilityTask = nil
        compatibility = .pending
        activeAdjustment = nil
        proposals.removeAll()
        results.removeAll()
        confirmed.removeAll()
        return pending
    }

    func retryCompatibility() {
        guard compatibility == .failed || compatibility == .incompatible else { return }
        compatibility = .pending
        receive()
    }

    func value(_ id: PowerModeAdjustmentID, map: Int) -> Double? {
        if let proposed = proposals[map]?[id] { return proposed }
        let configuration = context.telemetry.powerModeConfigurations[map]
        let read = id == .powerTraction ? configuration?.powerTractionPercent : configuration?.brakingTractionPercent
        return read ?? (compatibility == .compatible ? 0 : nil)
    }

    var allowsUnchangedCommit: Bool {
        let map = context.selectedMap
        return proposals[map] != nil
            || context.telemetry.powerModeConfigurations[map]?.hasTractionControlConfiguration != true
    }

    func clearFeedback() { results[context.selectedMap] = nil }

    func apply(_ id: PowerModeAdjustmentID, value: Double) {
        guard context.canUseConfiguration, compatibility == .compatible, !operations.isBusy,
              id == .powerTraction || id == .brakingTraction else { return }
        let map = context.selectedMap
        guard let power = self.value(.powerTraction, map: map), let braking = self.value(.brakingTraction, map: map),
              [power, braking, value].allSatisfy({ $0.isFinite
                  && 0 ... 100 ~= $0 && $0.rounded() == $0 }) else { return }
        let desiredPower = id == .powerTraction ? value : power
        let desiredBraking = id == .brakingTraction ? value : braking
        let expected = baseline(map)
        proposals[map] = [.powerTraction: desiredPower, .brakingTraction: desiredBraking]
        results[map] = nil
        activeAdjustment = id
        let apply = applyUseCase
        let token = generation
        operations.run(.basicWrite, execute: {
            try await apply.execute(
                mapIndex: map, powerTractionPercent: desiredPower, brakingTractionPercent: desiredBraking,
                expected: expected
            )
        }, completion: { [weak self] result in
            guard let self, self.generation == token else { return }
            self.activeAdjustment = nil
            self.store.invalidate(map)
            switch result {
            case .success(let actual):
                self.accept(actual)
                self.proposals[map] = nil
                self.results[map] = .confirmed(id)
            case .failure(let error): self.fail(error, map: map, id: id)
            }
        })
    }

    private func baseline(_ map: Int) -> BikeTractionControlSnapshot? {
        if proposals[map] != nil { return confirmed[map] }
        let configuration = context.telemetry.powerModeConfigurations[map]
        guard let power = configuration?.powerTractionPercent, let braking = configuration?.brakingTractionPercent,
              [power, braking].allSatisfy({ $0.isFinite && 0 ... 100 ~= $0 && $0.rounded() == $0 }) else { return nil }
        return .init(mapIndex: map, powerRaw: Int(power * 10), brakingRaw: Int(braking * 10))
    }

    private func accept(_ value: BikeTractionControlSnapshot) {
        confirmed[value.mapIndex] = value
        var configuration = context.telemetry.powerModeConfigurations[value.mapIndex] ?? .init(mapIndex: value.mapIndex)
        configuration.powerTractionPercent = Double(value.powerRaw) / 10
        configuration.brakingTractionPercent = Double(value.brakingRaw) / 10
        context.telemetry.powerModeConfigurations[value.mapIndex] = configuration
    }

    private func fail(_ error: any Error, map: Int, id: PowerModeAdjustmentID) {
        let message: String
        switch error as? BikeTractionControlError {
        case .changed(let actual):
            accept(actual)
            proposals[map] = nil
            message = String(localized: .powerModeSettingsTractionChanged)
        case .mismatch(let actual):
            accept(actual)
            message = String(localized: .powerModeSettingsTractionMismatch)
        case .connectionRecoveryRequired:
            confirmed[map] = nil
            message = String(localized: .powerModeSettingsTractionReconnect)
        case .rejected:
            message = String(localized: .powerModeSettingsApplyTractionError)
        case .unavailable:
            compatibility = .failed
            message = String(localized: .powerModeSettingsTractionControlsUnavailableError)
        default:
            confirmed[map] = nil
            message = String(localized: .powerModeSettingsTractionUnconfirmed)
        }
        results[map] = .failed(id, message: message)
    }
}
