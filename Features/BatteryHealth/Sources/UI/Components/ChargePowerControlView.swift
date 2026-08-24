import SwiftUI

struct ChargePowerControlView: View {
    let state: ChargePowerControlViewState
    let setDisplayedPower: (Double) -> Void
    let beginPowerDrag: () -> Void
    let endPowerDrag: () -> Void
    let setDisplayedTarget: (Double) -> Void
    let beginTargetDrag: () -> Void
    let endTargetDrag: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                    Text("\(Int(state.selectedWatts)) W")
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
                        get: { state.selectedWatts },
                        set: setDisplayedPower
                    ),
                    in: state.minimumWatts ... state.maximumWatts,
                    step: state.stepWatts,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            beginPowerDrag()
                        } else {
                            endPowerDrag()
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
                    Text("\(Int(state.selectedTargetPercent))%")
                        .font(.callout.weight(.semibold))
                }

                Slider(
                    value: Binding(
                        get: { state.selectedTargetPercent },
                        set: setDisplayedTarget
                    ),
                    in: state.minimumTargetPercent ... state.maximumTargetPercent,
                    step: state.targetStepPercent,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            beginTargetDrag()
                        } else {
                            endTargetDrag()
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
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let controlSpacing: CGFloat = 6
        static let labelSpacing: CGFloat = 2
    }
}
