import BikeEmulator
import SwiftUI

struct DebugPowerModeControls: View {
    @ObservedObject var controller: DebugScenarioController

    var body: some View {
        Section("FENRDebug") {
            Picker("Operational scenario", selection: scenarioBinding) {
                ForEach(BikeEmulatorScenario.allCases) { scenario in
                    Text(scenario.displayName).tag(scenario)
                }
            }
            Picker("Power mode data", selection: presetBinding) {
                ForEach(BikeEmulatorPowerModePreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            Picker("Active map", selection: mapBinding) {
                ForEach(Array(1 ... 5), id: \.self) { map in
                    Text("Map \(map)").tag(map)
                }
            }
            Text("Changes publish live telemetry and appear on the dashboard immediately.")
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
