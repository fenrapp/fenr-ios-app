import BikeDomain
import ChargeControl
@testable import ChargingSettings
import Foundation
import Testing

struct ChargingSettingsMapperTests {
    @Test func offlineSuggestionsAreNotConfirmed() {
        var state = ChargingPreferencesState()
        state.hasBike = true
        let mapped = ChargingSettingsMapper().map(state)
        #expect(mapped.power == 300)
        #expect(mapped.target == 100)
        #expect(!mapped.canEditPower)
        #expect(mapped.canEditTarget)
        #expect(!mapped.hasPendingChanges)
        #expect(mapped.canSelectCharger)
    }

    @Test func connectedChargerLocksSelectionAndPendingPowerIsNotSilentlyClamped() {
        var state = ChargingPreferencesState()
        state.hasBike = true
        state.isConnected = true
        state.isChargerConnected = true
        state.connectedCharger = .standard
        state.preferences.pendingPower = .init(watts: 7_000, charger: .fast, revision: UUID())
        state.failure = .chargerChanged
        let mapped = ChargingSettingsMapper().map(state)
        #expect(!mapped.canSelectCharger)
        #expect(mapped.maximumPower == 3_300)
        #expect(mapped.power == 7_000)
        let pendingPower = Measurement(value: 7_000, unit: UnitPower.watts)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        #expect(mapped.powerDetail.contains(pendingPower))
        #expect(mapped.hasPendingChanges)
        #expect(mapped.canRetry)
    }
}
