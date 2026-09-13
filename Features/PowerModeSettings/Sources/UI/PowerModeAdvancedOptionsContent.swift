import DesignSystem
import SwiftUI

struct PowerModeAdvancedOptionsContent: View {
    let state: PowerModeAdvancedViewState
    let maps: [PowerModeMapViewData]
    let send: (PowerModeAdvancedIntent) -> Void

    var body: some View {
        List {
            Section(.powerModeSettingsMapSection) {
                PowerModeSelector(maps: maps, select: { send(.selectMap($0)) })
                    .disabled(state.isBusy)
            }
            Section(.powerModeSettingsTractionGroupTitle) {
                ForEach(state.tractionAdjustments) { adjustment in
                    PowerModeAdjustmentRow(state: adjustment) { value in
                        send(.setTraction(id: adjustment.id, value: value))
                    }
                }
            }
            PowerCurvePresetsSection(state: state, send: send)
            Section {
                Label(.powerCurveSetting, systemImage: "minus")
                    .foregroundStyle(state.kind == .power ? DesignColor.warning : DesignColor.informational)
                Label(.powerCurveLimit, systemImage: "minus")
                    .foregroundStyle(DesignColor.secondaryText)
                Text(state.kind == .power ? .powerCurvePowerGuide : .powerCurveRegenGuide)
                Text(state.hasDraft ? .powerCurvePending : .powerCurveStored)
                if let message = state.message { Text(verbatim: message) }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(DesignSpace.medium)
        .contentMargins(.vertical, .zero, for: .scrollContent)
        .scrollContentBackground(.hidden)
    }
}
