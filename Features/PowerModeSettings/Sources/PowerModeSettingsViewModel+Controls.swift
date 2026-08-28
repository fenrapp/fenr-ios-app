import BikeDomain
import Foundation

public extension PowerModeSettingsViewModel {
    func updateAdjustment(id: String, value: Double) {
        switch id {
        case ControlConstants.powerAdjustmentID,
             ControlConstants.regenerationAdjustmentID:
            applyBaseAdjustment(id: id, value: value)
        case ControlConstants.powerTractionAdjustmentID,
             ControlConstants.brakingTractionAdjustmentID:
            applyTractionAdjustment(id: id, value: value)
        default:
            return
        }
    }
}

extension PowerModeSettingsViewModel {
    func applyBaseAdjustment(id: String, value: Double) {
        guard controlTask == nil,
              preparedBaseMapIndex == selectedMapIndex,
              let setPowerModeConfiguration = useCases.setPowerModeConfiguration,
              let configuration = telemetry.powerModeConfigurations[selectedMapIndex],
              let currentHorsepower = configuration.horsepower,
              let currentRegeneration = configuration.regenerativeBrakingPercent
        else {
            return
        }
        let horsepower = id == ControlConstants.powerAdjustmentID
            ? Int(value.rounded())
            : currentHorsepower
        let regeneration = id == ControlConstants.regenerationAdjustmentID
            ? Int(value.rounded())
            : Int(currentRegeneration.rounded())
        startControlWrite()
        let mapIndex = selectedMapIndex
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
                    values: .base(horsepower: horsepower, regeneration: regeneration),
                    error: nil
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishControlWrite(
                    mapIndex: mapIndex,
                    values: .base(horsepower: horsepower, regeneration: regeneration),
                    error: "Unable to apply map: \(error.localizedDescription)"
                )
            }
        }
    }

    func applyTractionAdjustment(id: String, value: Double) {
        guard controlTask == nil,
              preparedTractionMapIndex == selectedMapIndex,
              let setTractionControlConfiguration = useCases.setTractionControlConfiguration,
              let configuration = telemetry.powerModeConfigurations[selectedMapIndex],
              let currentPowerTraction = configuration.powerTractionPercent,
              let currentBrakingTraction = configuration.brakingTractionPercent
        else {
            return
        }
        let powerTraction = id == ControlConstants.powerTractionAdjustmentID
            ? value.rounded()
            : currentPowerTraction
        let brakingTraction = id == ControlConstants.brakingTractionAdjustmentID
            ? value.rounded()
            : currentBrakingTraction
        startControlWrite()
        let mapIndex = selectedMapIndex
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
                    values: .traction(power: powerTraction, braking: brakingTraction),
                    error: nil
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishControlWrite(
                    mapIndex: mapIndex,
                    values: .traction(power: powerTraction, braking: brakingTraction),
                    error: "Unable to apply traction control: \(error.localizedDescription)"
                )
            }
        }
    }

    func prepareControlIfPossible() {
        guard canPrepareSelectedMap,
              let preparePowerModeControl = useCases.preparePowerModeControl
        else {
            return
        }
        let mapIndex = selectedMapIndex
        let shouldPrepareTraction = telemetry.powerModeConfigurations[mapIndex]?
            .hasTractionControlConfiguration == true
        attemptedPreparationMapIndex = mapIndex
        isPreparingControl = true
        controlError = nil
        controlMessage = nil
        render()
        controlTask = Task { [weak self] in
            do {
                try await preparePowerModeControl.execute(mapIndex: mapIndex)
                guard !Task.isCancelled else { return }
                self?.preparedBaseMapIndex = mapIndex
                await self?.prepareTractionControlIfAvailable(
                    mapIndex: mapIndex,
                    isAvailable: shouldPrepareTraction
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishControlPreparation(
                    mapIndex: mapIndex,
                    tractionReady: false,
                    error: "Map controls unavailable: \(error.localizedDescription)"
                )
            }
        }
    }

    func resetControlState() {
        controlTask?.cancel()
        controlTask = nil
        preparedBaseMapIndex = nil
        preparedTractionMapIndex = nil
        attemptedPreparationMapIndex = nil
        isPreparingControl = false
        isApplyingControl = false
        controlMessage = nil
        controlError = nil
    }
}

private extension PowerModeSettingsViewModel {
    var canPrepareSelectedMap: Bool {
        !isRefreshing
            && controlTask == nil
            && preparedBaseMapIndex != selectedMapIndex
            && attemptedPreparationMapIndex != selectedMapIndex
            && isAuthenticated(connection.state)
            && telemetry.powerModeConfigurations[selectedMapIndex]?.hasBaseConfiguration == true
    }

    func prepareTractionControlIfAvailable(mapIndex: Int, isAvailable: Bool) async {
        guard isAvailable, let prepareTractionControl = useCases.prepareTractionControl else {
            finishControlPreparation(mapIndex: mapIndex, tractionReady: false, error: nil)
            return
        }
        do {
            try await prepareTractionControl.execute(mapIndex: mapIndex)
            guard !Task.isCancelled else { return }
            finishControlPreparation(mapIndex: mapIndex, tractionReady: true, error: nil)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            finishControlPreparation(
                mapIndex: mapIndex,
                tractionReady: false,
                error: "TC controls unavailable: \(error.localizedDescription)"
            )
        }
    }

    func startControlWrite() {
        isApplyingControl = true
        controlError = nil
        controlMessage = nil
        render()
    }

    func finishControlPreparation(
        mapIndex: Int,
        tractionReady: Bool,
        error: String?
    ) {
        controlTask = nil
        isPreparingControl = false
        guard mapIndex == selectedMapIndex else { return }
        controlError = error
        if preparedBaseMapIndex == mapIndex {
            preparedTractionMapIndex = tractionReady ? mapIndex : nil
            if error == nil {
                controlMessage = tractionReady
                    ? "All map controls ready"
                    : "Power and regeneration controls ready"
            }
        }
        render()
    }

    func finishControlWrite(
        mapIndex: Int,
        values: ConfirmedControlValues,
        error: String?
    ) {
        controlTask = nil
        isApplyingControl = false
        guard mapIndex == selectedMapIndex else { return }
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

    enum ControlConstants {
        static let powerAdjustmentID = "power"
        static let regenerationAdjustmentID = "regeneration"
        static let powerTractionAdjustmentID = "powerTraction"
        static let brakingTractionAdjustmentID = "brakingTraction"
    }
}
