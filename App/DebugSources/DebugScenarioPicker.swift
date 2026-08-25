import BikeEmulator
import SwiftUI

struct DebugScenarioPicker: View {
    @ObservedObject private var controller: DebugScenarioController

    init(controller: DebugScenarioController) {
        self.controller = controller
    }

    var body: some View {
        Menu {
            Picker("Scenario", selection: scenarioBinding) {
                ForEach(BikeEmulatorScenario.allCases) { scenario in
                    Text(scenario.displayName).tag(scenario)
                }
            }
        } label: {
            Label(
                "Debug: \(controller.selectedScenario.displayName)",
                systemImage: "wrench.and.screwdriver"
            )
            .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
        .background(.regularMaterial, in: Capsule())
        .padding(Constants.outerPadding)
        .accessibilityIdentifier("debug.scenarioPicker")
    }

    private var scenarioBinding: Binding<BikeEmulatorScenario> {
        Binding(
            get: { controller.selectedScenario },
            set: { scenario in
                controller.select(scenario)
            }
        )
    }

    private enum Constants {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let outerPadding: CGFloat = 8
    }
}
