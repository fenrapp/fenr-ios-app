import DesignSystem
import SwiftUI

struct ChargePowerControlView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: BatteryHealthChargeControlViewState
    let setPowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void

    init(
        state: BatteryHealthChargeControlViewState,
        setPowerLimit: @escaping (Double) -> Void,
        setChargeTarget: @escaping (Double) -> Void
    ) {
        self.state = state
        self.setPowerLimit = setPowerLimit
        self.setChargeTarget = setChargeTarget
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            controlSummary

            CommitSlider(
                value: state.power.selected,
                in: state.power.minimum ... state.power.maximum,
                step: state.power.step,
                isEnabled: state.isEnabled,
                accessibilityIdentifier: "batteryHealth.charging.power",
                onCommit: setPowerLimit,
                header: { value in
                    controlHeader(
                        title: BatteryHealthText.powerLimit,
                        value: "\(Int(value)) W",
                        valueIdentifier: "batteryHealth.charging.power.value"
                    )
                },
                footer: {
                    HStack {
                        Text(verbatim: "\(Int(state.power.minimum)) W")
                        Spacer()
                        Text(verbatim: "\(Int(state.power.maximum)) W")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            )

            CommitSlider(
                value: state.target.selected,
                in: state.target.minimum ... state.target.maximum,
                step: state.target.step,
                isEnabled: state.isEnabled,
                accessibilityIdentifier: "batteryHealth.charging.target",
                onCommit: setChargeTarget,
                header: { value in
                    controlHeader(
                        title: BatteryHealthText.chargeTarget,
                        value: "\(Int(value))%",
                        valueIdentifier: "batteryHealth.charging.target.value"
                    )
                },
                footer: {
                    HStack {
                        Text(verbatim: "\(Int(state.target.minimum))%")
                        Spacer()
                        Text(verbatim: "\(Int(state.target.maximum))%")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            )

            if let error = state.errorText {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder private var controlSummary: some View {
        let value = Text(verbatim: "\(Int(state.power.selected)) W")
            .font(.title3.weight(.semibold))
        let charger = Text(state.chargerText)
            .font(.caption)
            .foregroundStyle(.secondary)
        let status = Text(state.statusText)
            .font(.caption.weight(.medium))
            .foregroundStyle(state.statusIsError ? Color.red : Color.secondary)
            .accessibilityIdentifier("batteryHealth.charging.status")

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                value
                charger
                status
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                    value
                    charger
                }
                Spacer()
                status.multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private func controlHeader(title: String, value: String, valueIdentifier: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                Text(title)
                    .foregroundStyle(.secondary)
                Text(verbatim: value)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier(valueIdentifier)
            }
        } else {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: value)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier(valueIdentifier)
            }
        }
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let labelSpacing: CGFloat = 2
    }
}

#Preview("Charge power control") {
    ChargePowerControlView(
        state: .init(
            isVisible: true,
            isEnabled: true,
            power: .init(selected: 1_800, minimum: 300, maximum: 3_300, step: 100),
            target: .init(selected: 80, minimum: 1, maximum: 100, step: 1),
            chargerText: String(localized: .batteryHealthChargerStandard),
            statusText: String(localized: .batteryHealthChargeControlStatusReady)
        ),
        setPowerLimit: { _ in },
        setChargeTarget: { _ in }
    )
    .padding()
}
