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
        let generation = startControlWrite()
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
                    error: "Unable to apply map: \(error.localizedDescription)"
                )
            }
        }
    }

    func applyTractionAdjustment(id: PowerModeAdjustmentID, value: Double) {
        guard !isRefreshing,
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
        let generation = startControlWrite()
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
                    error: "Unable to apply traction control: \(error.localizedDescription)"
                )
            }
        }
    }
}

private extension PowerModeSettingsViewModel {
    func startControlWrite() -> Int {
        controlGeneration += 1
        isApplyingControl = true
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
              mapIndex == selectedMapIndex
        else {
            return
        }
        controlTask = nil
        isApplyingControl = false
        controlError = error
        if error == nil {
            applyConfirmed(values, mapIndex: mapIndex)
            controlMessage = "Map \(mapIndex + 1) confirmed by the bike"
        } else {
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
