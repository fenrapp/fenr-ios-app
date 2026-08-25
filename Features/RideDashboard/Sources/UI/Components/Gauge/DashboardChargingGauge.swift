import DesignSystem
import SwiftUI

struct DashboardChargingGauge: View {
    let state: ChargingDashboardGaugeViewState
    let reduceMotion: Bool
    let setPowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void

    @State private var interaction: ChargingGaugeInteractionState

    init(
        state: ChargingDashboardGaugeViewState,
        reduceMotion: Bool,
        setPowerLimit: @escaping (Double) -> Void = { _ in },
        setChargeTarget: @escaping (Double) -> Void = { _ in }
    ) {
        self.state = state
        self.reduceMotion = reduceMotion
        self.setPowerLimit = setPowerLimit
        self.setChargeTarget = setChargeTarget
        _interaction = State(
            initialValue: .init(
                displayedPowerWatts: state.control.power.selected,
                displayedTargetPercent: state.control.target.selected
            )
        )
    }

    var body: some View {
        ZStack {
            DashboardGauge(
                arc: {
                    DashboardGaugeArc(
                        progress: batteryProgress,
                        color: DesignColor.informational,
                        showsTicks: false,
                        targetProgress: targetProgress,
                        powerProgress: powerProgress,
                        controlsAreEnabled: controlsAreEnabled,
                        activeControl: interaction.activeControl,
                        reduceMotion: reduceMotion || interaction.activeControl != nil
                    )
                },
                readout: {
                    DashboardGaugeReadout(state: readoutState, reduceMotion: reduceMotion)
                }
            )
            if controlsAreEnabled {
                accessibilityControls
            }
        }
        .overlay { interactionLayer }
        .onChange(of: state.control.power.selected) { interaction.synchronizePower($0) }
        .onChange(of: state.control.target.selected) { interaction.synchronizeTarget($0) }
        .accessibilityLabel(accessibilityLabel)
    }

    private var controlsAreEnabled: Bool { state.control.isEnabled }

    private var batteryProgress: Double {
        min(max(Double(state.batteryPercent ?? .zero) / Constants.maximumPercentage, .zero), 1)
    }

    private var targetProgress: Double? {
        guard controlsAreEnabled else {
            return state.targetPercent.map {
                min(max(Double($0) / Constants.maximumPercentage, .zero), 1)
            }
        }
        return ChargingGaugeControlGeometry.normalizedProgress(
            value: interaction.displayedTargetPercent,
            minimum: state.control.target.minimum,
            maximum: state.control.target.maximum
        )
    }

    private var powerProgress: Double? {
        guard controlsAreEnabled else { return nil }
        return ChargingGaugeControlGeometry.normalizedProgress(
            value: interaction.displayedPowerWatts,
            minimum: state.control.power.minimum,
            maximum: state.control.power.maximum
        )
    }

    private var readoutState: DashboardGaugeReadoutState {
        let title = readoutTitle
        return .init(
            value: Double(state.batteryPercent ?? .zero),
            unit: nil,
            title: title.text,
            style: .percentage,
            titleStyle: title.style
        )
    }

    private var readoutTitle: (text: String, style: DashboardGaugeTitleStyle) {
        switch interaction.activeControl {
        case .target:
            return ("TARGET \(Int(interaction.displayedTargetPercent))%", .status)
        case .power:
            return ("POWER \(formattedPower(interaction.displayedPowerWatts))", .status)
        case nil:
            break
        }
        if let status = state.control.status {
            return (status.text, status.isError ? .error : .status)
        }
        return (
            state.readout.title,
            state.readout.usesEstimatedTimeStyle ? .estimatedTime : .status
        )
    }

    private var interactionLayer: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(controlsAreEnabled ? dragGesture(size: proxy.size) : nil)
        }
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: .zero)
            .onChanged { value in
                interaction.update(
                    startLocation: value.startLocation,
                    location: value.location,
                    geometry: .init(size: size),
                    controlState: state.control
                )
            }
            .onEnded { _ in
                switch interaction.finish() {
                case .target(let percent): setChargeTarget(percent)
                case .power(let watts): setPowerLimit(watts)
                case nil: break
                }
            }
    }

    private var accessibilityControls: some View {
        HStack(spacing: Constants.accessibilityControlSpacing) {
            adjustableAccessibilityControl(
                label: "Charge target",
                value: "\(Int(interaction.displayedTargetPercent)) percent",
                adjustment: adjustTarget
            )
            adjustableAccessibilityControl(
                label: "Charge power",
                value: formattedPower(interaction.displayedPowerWatts),
                adjustment: adjustPower
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func adjustableAccessibilityControl(
        label: String,
        value: String,
        adjustment: @escaping (AccessibilityAdjustmentDirection) -> Void
    ) -> some View {
        Rectangle()
            .fill(DesignColor.surface.opacity(Constants.accessibilityControlOpacity))
            .frame(width: Constants.accessibilityControlSize, height: Constants.accessibilityControlSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAdjustableAction(adjustment)
    }

    private func adjustTarget(_ direction: AccessibilityAdjustmentDirection) {
        let delta = direction == .increment ? state.control.target.step : -state.control.target.step
        let adjusted = min(
            max(interaction.displayedTargetPercent + delta, state.control.target.minimum),
            state.control.target.maximum
        )
        guard adjusted != interaction.displayedTargetPercent else { return }
        interaction.adjustTarget(adjusted)
        setChargeTarget(adjusted)
    }

    private func adjustPower(_ direction: AccessibilityAdjustmentDirection) {
        let delta = direction == .increment ? state.control.power.step : -state.control.power.step
        let adjusted = min(
            max(interaction.displayedPowerWatts + delta, state.control.power.minimum),
            state.control.power.maximum
        )
        guard adjusted != interaction.displayedPowerWatts else { return }
        interaction.adjustPower(adjusted)
        setPowerLimit(adjusted)
    }

    private var accessibilityLabel: String {
        state.readout.accessibilityLabel
    }

    private func formattedPower(_ watts: Double) -> String {
        let kilowatts = watts / 1_000
        return "\(kilowatts.formatted(.number.precision(.fractionLength(1)))) kW"
    }

    private enum Constants {
        static let maximumPercentage = 100.0
        static let accessibilityControlSize: CGFloat = 44
        static let accessibilityControlSpacing: CGFloat = 16
        static let accessibilityControlOpacity = 0.001
    }
}
