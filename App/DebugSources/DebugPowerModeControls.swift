import BikeEmulator
import Foundation
import SwiftUI

struct DebugPowerModeControls: View {
    @ObservedObject var controller: DebugScenarioController

    var body: some View {
        Section(.debugPowerModeSection) {
            Picker(selection: scenarioBinding) {
                ForEach(BikeEmulatorScenario.allCases) { scenario in
                    Text(scenario.localizedTitle).tag(scenario)
                }
            } label: {
                Text(.debugOperationalScenario)
            }
            Picker(selection: presetBinding) {
                ForEach(BikeEmulatorPowerModePreset.allCases) { preset in
                    Text(preset.localizedTitle).tag(preset)
                }
            } label: {
                Text(.debugPowerModeData)
            }
            Picker(selection: mapBinding) {
                ForEach(Array(1 ... 5), id: \.self) { map in
                    Text(.debugMapNumber(mapNumber: map)).tag(map)
                }
            } label: {
                Text(.debugActiveMap)
            }
            Text(.debugChangesPublishLive)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var scenarioBinding: Binding<BikeEmulatorScenario> {
        .init(
            get: { controller.selectedScenario },
            set: { controller.select($0) }
        )
    }

    private var presetBinding: Binding<BikeEmulatorPowerModePreset> {
        .init(
            get: { controller.selectedPowerModePreset },
            set: { controller.select($0) }
        )
    }

    private var mapBinding: Binding<Int> {
        .init(
            get: { controller.selectedMap },
            set: { controller.selectMap($0) }
        )
    }
}

private extension BikeEmulatorScenario {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .riding: .debugScenarioRiding
        case .ridingClean: .debugScenarioRidingClean
        case .charging: .debugScenarioCharging
        case .cellBalancing: .debugScenarioCellBalancing
        case .chargerIdle: .debugScenarioChargerIdle
        case .chargingDataUnavailable: .debugScenarioChargingUnavailable
        case .cellAnomaly: .debugScenarioCellAnomaly
        }
    }
}

private extension BikeEmulatorPowerModePreset {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .standard: .debugPresetStandard
        case .alpha: .debugPresetAlpha
        case .claimedAlpha: .debugPresetClaimedAlpha
        case .mismatch: .debugPresetMismatch
        case .partial: .debugPresetPartial
        case .failure: .debugPresetFailure
        }
    }
}
