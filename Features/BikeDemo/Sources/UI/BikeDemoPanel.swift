import DesignSystem
import SwiftUI

public struct BikeDemoPanel: View {
    @Environment(\.dismiss) private var dismiss
    private let state: BikeDemoViewState
    private let onSelect: (String) -> Void

    public init(state: BikeDemoViewState, onSelect: @escaping (String) -> Void) {
        self.state = state
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(state.scenarios) { scenario in
                        Button { onSelect(scenario.id) } label: {
                            BikeDemoScenarioRow(scenario: scenario, isSelected: state.selectedID == scenario.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("demo.scenario.\(scenario.id)")
                        .accessibilityAddTraits(state.selectedID == scenario.id ? .isSelected : [])
                    }
                } header: {
                    Text(.bikeDemoScenarioHeading)
                } footer: {
                    Text(.bikeDemoPersistence)
                }
                Section {
                    Text(.bikeDemoGPSDetail)
                    Text(.bikeDemoExitDetail)
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle(Text(.bikeDemoTitle))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(.bikeDemoDone) { dismiss() }
                }
            }
        }
    }
}
