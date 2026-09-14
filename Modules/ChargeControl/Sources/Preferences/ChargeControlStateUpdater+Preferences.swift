import BikeDomain

extension ChargeControlStateUpdater {
    func managedState(_ source: ChargingPreferencesState) -> ChargeControlState {
        let preferences = source.preferences
        let configuration = preferences.confirmed
        let charger = source.effectiveCharger
        let busy = source.isReading || source.isApplying
        let phase: ChargeControlPhase = source.failure != nil ? .failed : busy ? .updating : .ready
        return .init(
            isVisible: source.isChargerConnected,
            isEnabled: source.isConnected && source.failure == nil && charger != nil && configuration != nil,
            selectedWatts: Double(preferences.pendingPower?.watts ?? configuration?.chargePowerWatts ?? 300),
            confirmedWatts: configuration?.chargePowerWatts,
            maximumWatts: Double(charger?.maximumChargePowerWatts ?? 3_300),
            selectedTargetPercent: Double(
                preferences.pendingTarget?.percent
                    ?? configuration.map { $0.maximumStateOfChargeDeciPercent / 10 } ?? 100
            ),
            confirmedTargetPercent: configuration.map { $0.maximumStateOfChargeDeciPercent / 10 },
            chargerType: charger,
            status: source.failure != nil ? .updateFailed : busy ? .updating : .ready,
            failure: source.failure != nil ? .writeFailed : nil,
            phase: phase
        )
    }
}
