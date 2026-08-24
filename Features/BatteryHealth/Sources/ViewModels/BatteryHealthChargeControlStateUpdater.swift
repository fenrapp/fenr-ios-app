import BikeDomain

public struct BatteryHealthChargeControlStateUpdater {
    private let normalizer: BatteryHealthChargeControlNormalizer

    public init(normalizer: BatteryHealthChargeControlNormalizer) {
        self.normalizer = normalizer
    }

    func normalizedPowerWatts(_ watts: Int, state: ChargePowerControlViewState) -> Int {
        normalizer.powerWatts(watts, maximumWatts: Int(state.maximumWatts))
    }

    func normalizedTargetPercent(_ percent: Int) -> Int {
        normalizer.targetPercent(percent)
    }

    func applyPreparation(
        _ snapshot: BikeChargePowerControlSnapshot,
        to state: inout ChargePowerControlViewState
    ) {
        state.isVisible = true
        state.isEnabled = snapshot.didPassNoOpWrite
        state.status = snapshot.didPassNoOpWrite ? "Ready" : "No-op guard failed"
        state.error = nil
    }

    func applyPreparationFailure(
        _ error: Error,
        to state: inout ChargePowerControlViewState
    ) {
        state.isVisible = true
        state.isEnabled = false
        state.status = "Unavailable"
        state.error = String(describing: error)
    }

    func synchronize(
        charging: BikeChargingStatus,
        state: inout ChargePowerControlViewState,
        interaction: BatteryHealthChargeControlInteractionState
    ) -> BatteryHealthChargeControlConfirmedValues {
        state.isVisible = true
        state.minimumWatts = Double(BatteryHealthChargeControlConstants.defaultMinimumPowerWatts)
        state.maximumWatts = Double(charging.chargerType.maximumChargePowerWatts)
        state.stepWatts = Double(BatteryHealthChargeControlConstants.powerStepWatts)
        state.minimumTargetPercent = Double(BatteryHealthChargeControlConstants.minimumTargetPercent)
        state.maximumTargetPercent = Double(BatteryHealthChargeControlConstants.maximumTargetPercent)
        state.targetStepPercent = Double(BatteryHealthChargeControlConstants.targetStepPercent)
        state.chargerType = charging.chargerType.displayName

        let confirmed = BatteryHealthChargeControlConfirmedValues(
            watts: Int(charging.maximumPowerWatts.rounded()),
            targetPercent: normalizedTargetPercent(charging.maximumStateOfChargePercent)
        )
        state.confirmedWatts = confirmed.watts
        state.confirmedTargetPercent = confirmed.targetPercent
        synchronizePower(confirmed: confirmed.watts, interaction: interaction, state: &state)
        synchronizeTarget(confirmed: confirmed.targetPercent, interaction: interaction, state: &state)
        return confirmed
    }

    func restorePowerSelection(
        fallbackWatts: Int,
        state: inout ChargePowerControlViewState
    ) {
        state.selectedWatts = Double(normalizedPowerWatts(fallbackWatts, state: state))
    }

    func restoreTargetSelection(
        fallbackPercent: Int,
        state: inout ChargePowerControlViewState
    ) {
        state.selectedTargetPercent = Double(normalizedTargetPercent(fallbackPercent))
    }

    private func synchronizePower(
        confirmed: Int,
        interaction: BatteryHealthChargeControlInteractionState,
        state: inout ChargePowerControlViewState
    ) {
        let selected: Int?
        if interaction.isDraggingPower {
            selected = Int(state.selectedWatts.rounded())
        } else if let optimistic = interaction.optimisticPowerWatts {
            selected = optimistic
        } else if interaction.pendingPowerConfirmationWatts == nil {
            selected = confirmed
        } else {
            selected = nil
        }
        guard let selected else { return }
        state.selectedWatts = Double(normalizedPowerWatts(selected, state: state))
    }

    private func synchronizeTarget(
        confirmed: Int,
        interaction: BatteryHealthChargeControlInteractionState,
        state: inout ChargePowerControlViewState
    ) {
        let selected: Int?
        if interaction.isDraggingTarget {
            selected = Int(state.selectedTargetPercent.rounded())
        } else if let optimistic = interaction.optimisticTargetPercent {
            selected = optimistic
        } else if interaction.pendingTargetConfirmationPercent == nil {
            selected = confirmed
        } else {
            selected = nil
        }
        guard let selected else { return }
        state.selectedTargetPercent = Double(normalizedTargetPercent(selected))
    }
}

struct BatteryHealthChargeControlInteractionState {
    let isDraggingPower: Bool
    let optimisticPowerWatts: Int?
    let pendingPowerConfirmationWatts: Int?
    let isDraggingTarget: Bool
    let optimisticTargetPercent: Int?
    let pendingTargetConfirmationPercent: Int?
}

struct BatteryHealthChargeControlConfirmedValues {
    let watts: Int
    let targetPercent: Int
}
