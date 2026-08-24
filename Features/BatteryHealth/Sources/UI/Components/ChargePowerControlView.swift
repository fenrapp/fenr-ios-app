import SwiftUI

struct ChargePowerControlView: View {
    let state: ChargePowerControlViewState
    let setPowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void
    @State private var displayedPowerWatts: Double
    @State private var displayedTargetPercent: Double
    @State private var isEditingPower = false
    @State private var isEditingTarget = false

    init(
        state: ChargePowerControlViewState,
        setPowerLimit: @escaping (Double) -> Void,
        setChargeTarget: @escaping (Double) -> Void
    ) {
        self.state = state
        self.setPowerLimit = setPowerLimit
        self.setChargeTarget = setChargeTarget
        _displayedPowerWatts = State(initialValue: state.selectedWatts)
        _displayedTargetPercent = State(initialValue: state.selectedTargetPercent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                    Text("\(Int(displayedPowerWatts)) W")
                        .font(.title3.weight(.semibold))
                    Text("\(state.chargerType) charger")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(state.status)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(state.error == nil ? Color.secondary : Color.red)
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
                    in: state.minimumWatts ... state.maximumWatts,
                    step: state.stepWatts,
                    onEditingChanged: { isEditing in
                        isEditingPower = isEditing
                        if !isEditing {
                            setPowerLimit(displayedPowerWatts)
                        }
                    }
                )
                .disabled(!state.isEnabled)

                HStack {
                    Text("\(Int(state.minimumWatts)) W")
                    Spacer()
                    Text("\(Int(state.maximumWatts)) W")
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
                    in: state.minimumTargetPercent ... state.maximumTargetPercent,
                    step: state.targetStepPercent,
                    onEditingChanged: { isEditing in
                        isEditingTarget = isEditing
                        if !isEditing {
                            setChargeTarget(displayedTargetPercent)
                        }
                    }
                )
                .disabled(!state.isEnabled)

                HStack {
                    Text("\(Int(state.minimumTargetPercent))%")
                    Spacer()
                    Text("\(Int(state.maximumTargetPercent))%")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if let error = state.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: state.selectedWatts) { value in
            guard !isEditingPower else { return }
            displayedPowerWatts = value
        }
        .onChange(of: state.selectedTargetPercent) { value in
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
