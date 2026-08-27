import SwiftUI

struct ChargePowerControlView: View {
    let state: BatteryHealthChargeControlViewState
    let setPowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void
    @State private var displayedPowerWatts: Double
    @State private var displayedTargetPercent: Double
    @State private var isEditingPower = false
    @State private var isEditingTarget = false

    init(
        state: BatteryHealthChargeControlViewState,
        setPowerLimit: @escaping (Double) -> Void,
        setChargeTarget: @escaping (Double) -> Void
    ) {
        self.state = state
        self.setPowerLimit = setPowerLimit
        self.setChargeTarget = setChargeTarget
        _displayedPowerWatts = State(initialValue: state.power.selected)
        _displayedTargetPercent = State(initialValue: state.target.selected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                    Text("\(Int(displayedPowerWatts)) W")
                        .font(.title3.weight(.semibold))
                    Text(state.chargerText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(state.statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(state.statusIsError ? Color.red : Color.secondary)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: Constants.controlSpacing) {
                Text("Power limit")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { displayedPowerWatts },
                        set: { displayedPowerWatts = $0 }
                    ),
                    in: state.power.minimum ... state.power.maximum,
                    step: state.power.step,
                    onEditingChanged: { isEditing in
                        isEditingPower = isEditing
                        if !isEditing {
                            guard displayedPowerWatts != state.power.selected else { return }
                            setPowerLimit(displayedPowerWatts)
                        }
                    }
                )
                .disabled(!state.isEnabled)

                HStack {
                    Text("\(Int(state.power.minimum)) W")
                    Spacer()
                    Text("\(Int(state.power.maximum)) W")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Constants.controlSpacing) {
                HStack {
                    Text("Charge target")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(displayedTargetPercent))%")
                        .font(.callout.weight(.semibold))
                }

                Slider(
                    value: Binding(
                        get: { displayedTargetPercent },
                        set: { displayedTargetPercent = $0 }
                    ),
                    in: state.target.minimum ... state.target.maximum,
                    step: state.target.step,
                    onEditingChanged: { isEditing in
                        isEditingTarget = isEditing
                        if !isEditing {
                            guard displayedTargetPercent != state.target.selected else { return }
                            setChargeTarget(displayedTargetPercent)
                        }
                    }
                )
                .disabled(!state.isEnabled)

                HStack {
                    Text("\(Int(state.target.minimum))%")
                    Spacer()
                    Text("\(Int(state.target.maximum))%")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if let error = state.errorText {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: state.power.selected) { _, value in
            guard !isEditingPower else { return }
            displayedPowerWatts = value
        }
        .onChange(of: state.target.selected) { _, value in
            guard !isEditingTarget else { return }
            displayedTargetPercent = value
        }
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let controlSpacing: CGFloat = 6
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
            chargerText: "Standard charger",
            statusText: "Ready"
        ),
        setPowerLimit: { _ in },
        setChargeTarget: { _ in }
    )
    .padding()
}
