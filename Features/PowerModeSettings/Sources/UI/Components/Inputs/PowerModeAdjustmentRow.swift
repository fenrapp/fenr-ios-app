import DesignSystem
import Foundation
import SwiftUI

struct PowerModeAdjustmentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: PowerModeAdjustmentViewState
    let commit: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            if let value = state.value {
                CommitSlider(
                    value: value,
                    in: state.minimum ... state.maximum,
                    step: state.step,
                    appearance: appearance,
                    isEnabled: state.isEnabled,
                    accessibilityLabel: state.title,
                    accessibilityValue: valueText,
                    onCommit: commit,
                    header: { displayedValue in
                        adjustmentHeader(displayedValue)
                    },
                    footer: {
                        adjustmentFooter
                    }
                )
            } else {
                adjustmentHeader(state.minimum)
            }

            if state.feedback.state != .idle {
                PowerModeControlFeedbackView(feedback: state.feedback)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func adjustmentHeader(_ displayedValue: Double) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                title
                value(displayedValue)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack {
                title
                Spacer()
                value(displayedValue)
            }
        }
    }

    private var title: some View {
        Text(state.title)
            .font(.callout.weight(.medium))
    }

    private func value(_ displayedValue: Double) -> some View {
        Text(valueText(displayedValue))
            .font(.callout.weight(.semibold))
            .monospacedDigit()
    }

    private func valueText(_ displayedValue: Double) -> String {
        guard state.value != nil else { return state.valueText }
        let value = state.isEnabled ? formatted(displayedValue) : state.valueText
        return String(localized: .powerModeSettingsMeasurement(value, state.unit))
    }

    private var adjustmentFooter: some View {
        HStack {
            Text(measurement(state.minimum))
            Spacer()
            Text(measurement(state.maximum))
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(DesignColor.secondaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(.powerModeSettingsRangeAccessibility(
                measurement(state.minimum),
                measurement(state.maximum)
            ))
        )
    }

    private var appearance: CommitSliderAppearance {
        switch state.id {
        case .power, .regeneration:
            .init(
                gradientStops: [
                    .init(color: Color.yellow, location: 0),
                    .init(color: Color.orange, location: 1)
                ]
            )
        case .powerTraction, .brakingTraction:
            .init(
                gradientStops: [
                    .init(color: Color.teal, location: 0),
                    .init(color: Color.blue, location: 1)
                ]
            )
        }
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: state.localeIdentifier))
                .precision(.fractionLength(0 ... 1))
        )
    }

    private func measurement(_ value: Double) -> String {
        String(localized: .powerModeSettingsMeasurement(formatted(value), state.unit))
    }

    private enum Constants {
        static let spacing = DesignSpace.extraSmall
    }
}
