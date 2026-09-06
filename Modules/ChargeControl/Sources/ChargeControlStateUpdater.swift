import BikeDomain

public struct ChargeControlStateUpdater {
    private let normalizer: ChargeControlNormalizer

    public init(normalizer: ChargeControlNormalizer) {
        self.normalizer = normalizer
    }

    func normalizedPowerWatts(_ watts: Int, state: ChargeControlState) -> Int {
        normalizer.powerWatts(watts, maximumWatts: Int(state.maximumWatts))
    }

    func normalizedTargetPercent(_ percent: Int) -> Int { normalizer.targetPercent(percent) }

    func applyPreparation(_ snapshot: BikeChargePowerControlSnapshot, to state: inout ChargeControlState) {
        state.isVisible = true
        guard snapshot.isFirmwareCompatible else {
            state.isEnabled = false
            state.status = .unsupportedFirmware
            state.phase = .failed
            state.failure = .incompatibleFirmware
            return
        }
        state.isEnabled = snapshot.didPassNoOpWrite
        state.status = snapshot.didPassNoOpWrite ? .ready : .noOpGuardFailed
        state.phase = snapshot.didPassNoOpWrite ? .ready : .failed
        state.failure = snapshot.didPassNoOpWrite ? nil : .noOpValidationFailed
    }

    func applyPreparationFailure(to state: inout ChargeControlState) {
        state.isVisible = true
        state.isEnabled = false
        state.status = .unavailable
        state.phase = .failed
        state.failure = .preparationFailed
    }

    func synchronize(
        charging: BikeChargingStatus,
        state: inout ChargeControlState,
        interaction: ChargeControlInteractionState
    ) -> ChargeControlConfirmedValues {
        state.isVisible = true
        state.minimumWatts = Double(ChargeControlConstants.minimumPowerWatts)
        state.maximumWatts = Double(charging.chargerType.maximumChargePowerWatts)
        state.stepWatts = Double(ChargeControlConstants.powerStepWatts)
        state.minimumTargetPercent = Double(ChargeControlConstants.minimumTargetPercent)
        state.maximumTargetPercent = Double(ChargeControlConstants.maximumTargetPercent)
        state.targetStepPercent = Double(ChargeControlConstants.targetStepPercent)
        state.chargerType = charging.chargerType

        let confirmed = ChargeControlConfirmedValues(
            watts: Int(charging.maximumPowerWatts.rounded()),
            targetPercent: normalizedTargetPercent(charging.maximumStateOfChargePercent)
        )
        state.confirmedWatts = confirmed.watts
        state.confirmedTargetPercent = confirmed.targetPercent
        if let optimistic = interaction.optimisticPowerWatts {
            state.selectedWatts = Double(normalizedPowerWatts(optimistic, state: state))
        } else if interaction.pendingPowerConfirmationWatts == nil {
            state.selectedWatts = Double(normalizedPowerWatts(confirmed.watts, state: state))
        }
        if let optimistic = interaction.optimisticTargetPercent {
            state.selectedTargetPercent = Double(normalizedTargetPercent(optimistic))
        } else if interaction.pendingTargetConfirmationPercent == nil {
            state.selectedTargetPercent = Double(confirmed.targetPercent)
        }
        return confirmed
    }

    func restorePowerSelection(fallbackWatts: Int, state: inout ChargeControlState) {
        state.selectedWatts = Double(normalizedPowerWatts(fallbackWatts, state: state))
    }

    func restoreTargetSelection(fallbackPercent: Int, state: inout ChargeControlState) {
        state.selectedTargetPercent = Double(normalizedTargetPercent(fallbackPercent))
    }
}

struct ChargeControlInteractionState {
    let optimisticPowerWatts: Int?
    let pendingPowerConfirmationWatts: Int?
    let optimisticTargetPercent: Int?
    let pendingTargetConfirmationPercent: Int?
}

struct ChargeControlConfirmedValues {
    let watts: Int
    let targetPercent: Int
}
