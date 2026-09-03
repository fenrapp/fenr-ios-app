import BikeDomain
import Foundation

public extension PowerModeSettingsViewModel {
    func updateAdjustment(id: PowerModeAdjustmentID, value: Double) {
        guard let adjustment = viewState.adjustments.first(where: { $0.id == id }),
              adjustment.isEnabled,
              adjustment.accepts(value)
        else {
            return
        }
        switch id {
        case .power, .regeneration:
            applyBaseAdjustment(id: id, value: value)
        case .powerTraction, .brakingTraction:
            applyTractionAdjustment(id: id, value: value)
        }
    }
}

extension PowerModeSettingsViewModel {
    func applyBaseAdjustment(id: PowerModeAdjustmentID, value: Double) {
        guard !isRefreshing,
              isCanonicalTelemetryAvailable,
              controlTask == nil,
              preparedBaseMapIndex == selectedMapIndex,
              let configuration = telemetry.powerModeConfigurations[selectedMapIndex],
              let currentHorsepower = configuration.horsepower,
              let currentRegeneration = configuration.regenerativeBrakingPercent
        else {
            return
        }
        let horsepower = id == .power ? Int(value.rounded()) : currentHorsepower
        let regeneration = id == .regeneration
            ? Int(value.rounded())
            : Int(currentRegeneration.rounded())
        let mapIndex = selectedMapIndex
        let generation = startControlWrite(adjustmentID: id)
        let setPowerModeConfiguration = useCases.setPowerModeConfiguration
        controlTask = Task { [weak self] in
            do {
                try await setPowerModeConfiguration.execute(
                    mapIndex: mapIndex,
                    horsepower: horsepower,
                    regenerativeBrakingPercent: regeneration
                )
                guard !Task.isCancelled else { return }
                self?.finishControlWrite(
                    mapIndex: mapIndex,
                    generation: generation,
                    values: .base(horsepower: horsepower, regeneration: regeneration),
                    error: nil
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishControlWrite(
                    mapIndex: mapIndex,
                    generation: generation,
                    values: .base(horsepower: horsepower, regeneration: regeneration),
                    error: String(localized: .powerModeSettingsApplyMapError)
                )
            }
        }
    }

    func applyTractionAdjustment(id: PowerModeAdjustmentID, value: Double) {
        guard !isRefreshing,
              isCanonicalTelemetryAvailable,
              controlTask == nil,
              preparedTractionMapIndex == selectedMapIndex,
              let configuration = telemetry.powerModeConfigurations[selectedMapIndex],
              let currentPowerTraction = configuration.powerTractionPercent,
              let currentBrakingTraction = configuration.brakingTractionPercent
        else {
            return
        }
        let powerTraction = id == .powerTraction ? value : currentPowerTraction
        let brakingTraction = id == .brakingTraction ? value : currentBrakingTraction
        guard isSupportedTractionValue(powerTraction),
              isSupportedTractionValue(brakingTraction)
        else {
            return
        }
        let mapIndex = selectedMapIndex
        let generation = startControlWrite(adjustmentID: id)
        let setTractionControlConfiguration = useCases.setTractionControlConfiguration
        controlTask = Task { [weak self] in
            do {
                try await setTractionControlConfiguration.execute(
                    mapIndex: mapIndex,
                    powerTractionPercent: powerTraction,
                    brakingTractionPercent: brakingTraction
                )
                guard !Task.isCancelled else { return }
                self?.finishControlWrite(
                    mapIndex: mapIndex,
                    generation: generation,
                    values: .traction(power: powerTraction, braking: brakingTraction),
                    error: nil
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishControlWrite(
                    mapIndex: mapIndex,
                    generation: generation,
                    values: .traction(power: powerTraction, braking: brakingTraction),
                    error: String(localized: .powerModeSettingsApplyTractionError)
                )
            }
        }
    }
}

private extension PowerModeSettingsViewModel {
    func startControlWrite(adjustmentID: PowerModeAdjustmentID) -> Int {
        controlGeneration += 1
        isApplyingControl = true
        activeAdjustmentID = adjustmentID
        recentAdjustmentResult = nil
        controlError = nil
        controlMessage = nil
        render()
        return controlGeneration
    }

    func finishControlWrite(
        mapIndex: Int,
        generation: Int,
        values: ConfirmedControlValues,
        error: String?
    ) {
        guard generation == controlGeneration,
              mapIndex == selectedMapIndex,
              isCanonicalTelemetryAvailable
        else {
            return
        }
        controlTask = nil
        isApplyingControl = false
        let adjustmentID = activeAdjustmentID
        activeAdjustmentID = nil
        controlError = error
        if error == nil {
            applyConfirmed(values, mapIndex: mapIndex)
            recentAdjustmentResult = adjustmentID.map(PowerModeAdjustmentResult.confirmed)
            controlMessage = String(
                localized: .powerModeSettingsMapConfirmed(mapIndex + 1)
            )
        } else {
            recentAdjustmentResult = adjustmentID.map {
                .failed($0, message: error ?? "")
            }
            clearPreparation(for: values)
            attemptedPreparationMapIndex = mapIndex
        }
        render()
    }

    func applyConfirmed(_ values: ConfirmedControlValues, mapIndex: Int) {
        switch values {
        case .base(let horsepower, let regeneration):
            telemetry.powerModeConfigurations[mapIndex]?.horsepower = horsepower
            telemetry.powerModeConfigurations[mapIndex]?.regenerativeBrakingPercent = Double(regeneration)
        case .traction(let power, let braking):
            telemetry.powerModeConfigurations[mapIndex]?.powerTractionPercent = power
            telemetry.powerModeConfigurations[mapIndex]?.brakingTractionPercent = braking
        }
    }

    func clearPreparation(for values: ConfirmedControlValues) {
        switch values {
        case .base: preparedBaseMapIndex = nil
        case .traction: preparedTractionMapIndex = nil
        }
    }

    enum ConfirmedControlValues {
        case base(horsepower: Int, regeneration: Int)
        case traction(power: Double, braking: Double)
    }

    func isSupportedTractionValue(_ value: Double) -> Bool {
        value.isFinite && 0 ... 100 ~= value && value.rounded() == value
    }
}

private extension PowerModeAdjustmentViewState {
    func accepts(_ candidate: Double) -> Bool {
        guard candidate.isFinite,
              minimum ... maximum ~= candidate,
              step.isFinite,
              step > 0
        else {
            return false
        }
        let stepCount = (candidate - minimum) / step
        return stepCount.rounded() == stepCount
    }
}
