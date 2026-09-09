import DesignSystem
import Foundation
import SwiftUI

struct PowerModeAdjustmentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showsExactValue = false

    let state: PowerModeAdjustmentViewState
    let allowsExactValue: Bool
    let commit: (Double) -> Void

    init(
        state: PowerModeAdjustmentViewState, allowsExactValue: Bool = false,
        commit: @escaping (Double) -> Void
    ) {
        self.state = state
        self.allowsExactValue = allowsExactValue
        self.commit = commit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            adjustmentControl

            if state.feedback.state != .idle {
                PowerModeControlFeedbackView(feedback: state.feedback)
            }
        }
        .sheet(isPresented: $showsExactValue) {
            if let value = state.value {
                PowerModeValueInput(
                    title: state.title, value: value, bounds: state.minimum ... state.maximum,
                    wholeNumbersOnly: true, hint: .powerModeSettingsExactValueHint,
                    confirmationTitle: .powerCurveApply, unit: state.unit, commit: commit
                )
            }
        }
        .onChange(of: state.isEnabled) { _, enabled in
            if !enabled { showsExactValue = false }
        }
        .onChange(of: state.id) { showsExactValue = false }
        .accessibilityActions {
            if allowsExactValue, state.isEnabled {
                Button(.powerCurveExactValue, action: openExactValue)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("powerModes.adjustment." + state.id.rawValue)
    }

    @ViewBuilder
    private var adjustmentControl: some View {
        if let value = state.value {
            CommitSlider(
                value: value,
                in: state.minimum ... state.maximum,
                step: state.step,
                appearance: appearance,
                isEnabled: state.isEnabled,
                allowsUnchangedCommit: state.allowsUnchangedCommit,
                accessibilityLabel: state.title,
                accessibilityValue: valueText,
                onDoubleTap: exactValueAction,
                accessibilityIdentifier: "powerModes.control." + state.id.rawValue,
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
    }

    private var exactValueAction: (() -> Void)? {
        guard allowsExactValue else { return nil }
        return { openExactValue() }
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
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: openExactValue)
            .accessibilityHint(allowsExactValue
                ? Text(.powerModeSettingsExactValueAccessibility) : Text(verbatim: ""))
    }

    private func openExactValue() {
        guard allowsExactValue, state.isEnabled, state.value != nil else { return }
        showsExactValue = true
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
