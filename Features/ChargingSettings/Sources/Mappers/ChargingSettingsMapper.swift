import BikeDomain
import ChargeControl
import Foundation

public struct ChargingSettingsMapper {
    public init() {}

    public func map(_ state: ChargingPreferencesState) -> ChargingSettingsViewState {
        let preferences = state.preferences
        let confirmed = preferences.confirmed
        let charger = state.effectiveCharger
        let busy = state.isApplying || state.isReading
        let canEdit = state.hasBike && state.failure != .storage
        return .init(
            power: Double(preferences.pendingPower?.watts ?? confirmed?.chargePowerWatts ?? 300),
            target: Double(preferences.pendingTarget?.percent
                ?? confirmed.map { $0.maximumStateOfChargeDeciPercent / 10 } ?? 100),
            maximumPower: Double(charger?.maximumChargePowerWatts ?? 3_300),
            selectedChargerID: charger.flatMap { isKnown($0) ? String($0.rawValue) : nil } ?? "",
            canSelectCharger: canEdit && !state.isChargerConnected,
            canEditPower: canEdit && charger.map(isKnown) == true,
            canEditTarget: canEdit,
            powerDetail: detail(
                confirmed.map { powerText($0.chargePowerWatts) },
                pending: preferences.pendingPower.map { powerText($0.watts) },
                fresh: state.hasFreshConfiguration
            ),
            targetDetail: detail(
                confirmed.map { (Double($0.maximumStateOfChargeDeciPercent) / 1_000).formatted(.percent) },
                pending: preferences.pendingTarget.map { (Double($0.percent) / 100).formatted(.percent) },
                fresh: state.hasFreshConfiguration
            ),
            status: status(state), isBusy: busy,
            hasPendingChanges: preferences.hasPendingChanges,
            canRetry: state.failure != nil && !busy
        )
    }

    private func isKnown(_ charger: BikeChargerType) -> Bool {
        if case .unknown = charger { false } else { true }
    }

    private func powerText(_ watts: Int) -> String {
        Measurement(value: Double(watts), unit: UnitPower.watts)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
    }

    private func detail(_ confirmed: String?, pending: String?, fresh: Bool) -> String {
        let reading: String
        if let confirmed {
            reading = fresh
                ? String(localized: .chargingSettingsConfirmed(confirmed))
                : String(localized: .chargingSettingsLastReading(confirmed))
        } else {
            reading = String(localized: .chargingSettingsSuggested)
        }
        guard let pending else { return reading }
        return String(localized: .chargingSettingsPendingDetail(pending, reading))
    }

    private func status(_ state: ChargingPreferencesState) -> String {
        if let failure = state.failure {
            switch failure {
            case .storage: return String(localized: .chargingSettingsStorageError)
            case .incompatibleFirmware: return String(localized: .chargingSettingsFirmwareError)
            case .chargerChanged: return String(localized: .chargingSettingsChargerError)
            case .confirmation, .unavailable: return String(localized: .chargingSettingsWriteError)
            case .invalidValue: return String(localized: .chargingSettingsValueError)
            }
        }
        if !state.hasBike { return String(localized: .chargingSettingsNoBike) }
        if state.isApplying { return String(localized: .chargingSettingsApplying) }
        if state.isReading { return String(localized: .chargingSettingsReading) }
        if state.preferences.hasPendingChanges { return String(localized: .chargingSettingsPending) }
        return state.isConnected
            ? String(localized: .chargingSettingsConnected)
            : String(localized: .chargingSettingsOffline)
    }
}
