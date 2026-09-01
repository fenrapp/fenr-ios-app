import DesignSystem
import Foundation
import SwiftUI

struct PowerModeAdjustmentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            adjustmentHeader

            if state.value != nil {
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
                .onChange(of: state) { _, nextState in
                    guard let nextValue = nextState.value else { return }
                    draftValue = Self.clamped(nextValue, to: nextState)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var adjustmentHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                title
                value
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack {
                title
                Spacer()
                value
            }
        }
    }

    private var title: some View {
        Text(state.title)
            .font(.callout.weight(.medium))
    }

    private var value: some View {
        Text(valueText)
            .font(.callout.weight(.semibold))
            .monospacedDigit()
    }

    private var valueText: String {
        guard state.value != nil else { return state.valueText }
        let value = state.isEnabled ? formatted(draftValue) : state.valueText
        return "\(value) \(state.unit)"
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: state.localeIdentifier))
                .precision(.fractionLength(0 ... 1))
        )
    }

    private static func clamped(_ value: Double, to state: PowerModeAdjustmentViewState) -> Double {
        min(max(value, state.minimum), state.maximum)
    }

    private enum Constants {
        static let spacing = DesignSpace.extraSmall
    }
}
