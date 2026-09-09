import DesignSystem
import SwiftUI

struct PowerCurveActionButtons: View {
    let state: PowerModeAdvancedViewState
    let send: (PowerModeAdvancedIntent) -> Void

    var body: some View {
        HStack(spacing: DesignSpace.small) {
            Spacer()
            Button(.powerCurveDiscard) { send(.discard) }
                .buttonStyle(.bordered)
                .disabled(!state.hasDraft || state.isBusy)
            Button(.powerCurveApply) { send(.apply) }
                .buttonStyle(.borderedProminent)
                .disabled(!state.canApply)
        }
        .controlSize(.regular)
        .padding(.vertical, DesignSpace.extraSmall)
    }
}
