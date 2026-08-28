import SwiftUI

struct PowerModeAdjustmentRow: View {
    let state: PowerModeAdjustmentViewState
    let commit: (Double) -> Void
    @State private var draftValue: Double

    init(state: PowerModeAdjustmentViewState, commit: @escaping (Double) -> Void) {
        self.state = state
        self.commit = commit
        _draftValue = State(
            initialValue: state.value.map { Self.clamped($0, to: state) } ?? state.minimum
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            HStack {
                Text(state.title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(valueText)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }

            if let value = state.value {
                Slider(
                    value: $draftValue,
                    in: state.minimum ... state.maximum,
                    step: state.step,
                    onEditingChanged: { isEditing in
                        guard !isEditing else { return }
                        commit(draftValue)
                    }
                )
                .disabled(!state.isEnabled)
                .onChange(of: value) { nextValue in
                    draftValue = Self.clamped(nextValue, to: state)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var valueText: String {
        guard state.value != nil else { return state.valueText }
        let value = state.isEnabled ? formatted(draftValue) : state.valueText
        return "\(value) \(state.unit)"
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func clamped(_ value: Double, to state: PowerModeAdjustmentViewState) -> Double {
        min(max(value, state.minimum), state.maximum)
    }

    private enum Constants {
        static let spacing: CGFloat = 8
    }
}
