import DesignSystem
import SwiftUI

struct DashboardChargingCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewState: ChargingDashboardViewState
    let setPowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void

    @State private var displayedPowerWatts: Double
    @State private var displayedTargetPercent: Double
    @State private var isEditingPower = false
    @State private var isEditingTarget = false
    @State private var selectionFeedbackTrigger = 0

    init(
        viewState: ChargingDashboardViewState,
        setPowerLimit: @escaping (Double) -> Void,
        setChargeTarget: @escaping (Double) -> Void
    ) {
        self.viewState = viewState
        self.setPowerLimit = setPowerLimit
        self.setChargeTarget = setChargeTarget
        _displayedPowerWatts = State(initialValue: viewState.control.power.selected)
        _displayedTargetPercent = State(initialValue: viewState.control.target.selected)
    }

    var body: some View {
        VStack(spacing: Constants.sectionSpacing) {
            chargingStatus
            chargeControl(
                configuration: .init(
                    title: "Max Charging Power",
                    adjustment: viewState.control.power,
                    tint: DesignColor.informational,
                    valueFormatter: formattedPower
                ),
                value: $displayedPowerWatts,
                isEditing: $isEditingPower,
                commit: setPowerLimit
            )
            chargeControl(
                configuration: .init(
                    title: "Charge Limit",
                    adjustment: viewState.control.target,
                    tint: DesignColor.positive,
                    valueFormatter: formattedPercentage
                ),
                value: $displayedTargetPercent,
                isEditing: $isEditingTarget,
                commit: setChargeTarget
            )
            DashboardChargingMetricsRow(
                power: viewState.chargingPower,
                current: viewState.reportedCurrent,
                temperature: viewState.batteryTemperature,
                temperatureEmphasis: viewState.batteryTemperatureEmphasis,
                activeBalancingCells: viewState.isBalancingAtFullCharge
                    ? viewState.activeBalancingCells
                    : nil
            )
        }
        .padding(Constants.contentPadding)
        .background(cardShape.fill(DesignColor.groupedSurface))
        .overlay {
            DashboardChargingProgressBorder(
                progress: chargingProgressIfVisible,
                cornerRadius: Constants.cornerRadius,
                isBalancing: viewState.isBalancingAtFullCharge
            )
        }
        .padding(.horizontal, Constants.horizontalInset)
        .padding(.vertical, Constants.verticalInset)
        .onChange(of: viewState.control.power.selected) { _, value in
            guard !isEditingPower else { return }
            displayedPowerWatts = value
        }
        .onChange(of: viewState.control.target.selected) { _, value in
            guard !isEditingTarget else { return }
            displayedTargetPercent = value
        }
        .animation(.easeInOut(duration: Constants.statusAnimationDuration), value: viewState.control.status)
        .dashboardChargingHapticFeedback(
            selectionTrigger: selectionFeedbackTrigger,
            status: viewState.control.status
        )
        .accessibilityElement(children: .contain)
    }

    private var chargingStatus: some View {
        HStack(spacing: DesignSpace.medium) {
            DashboardChargingHeaderIcon(
                systemImage: chargingSystemImage,
                color: chargingIconColor,
                showsActivityIndicator: viewState.control.status?.showsActivityIndicator == true
            )

            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(viewState.readout.title)
                    .font(.system(size: Constants.readoutFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(readoutColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.readoutMinimumScaleFactor)
                if let subtitle = chargingSubtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(chargingSubtitleColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewState.readout.accessibilityLabel)
    }

    private func chargeControl(
        configuration: ControlConfiguration,
        value: Binding<Double>,
        isEditing: Binding<Bool>,
        commit: @escaping (Double) -> Void
    ) -> some View {
        let isEnabled = controlIsEnabled(configuration.adjustment)
        return VStack(spacing: Constants.controlSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(configuration.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DesignColor.secondaryText)
                Spacer()
                Text(configuration.valueFormatter(value.wrappedValue))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignColor.primaryText)
            }

            Slider(
                value: value,
                in: configuration.adjustment.minimum ... configuration.adjustment.maximum,
                step: configuration.adjustment.step,
                onEditingChanged: { editing in
                    isEditing.wrappedValue = editing
                    guard
                        !editing,
                        isEnabled,
                        value.wrappedValue != configuration.adjustment.selected
                    else { return }
                    selectionFeedbackTrigger += 1
                    commit(value.wrappedValue)
                }
            )
            .tint(configuration.tint)
            .disabled(!isEnabled)

            HStack {
                limitLabel(
                    "MIN",
                    value: configuration.valueFormatter(configuration.adjustment.minimum)
                )
                Spacer()
                limitLabel(
                    "MAX",
                    value: configuration.valueFormatter(configuration.adjustment.maximum)
                )
            }
        }
        .opacity(isEnabled ? 1 : Constants.disabledOpacity)
        .accessibilityElement(children: .contain)
    }

    private func controlIsEnabled(_ adjustment: ChargingDashboardAdjustmentViewState) -> Bool {
        viewState.control.isEnabled
            && adjustment.isEnabled
            && viewState.readout.allowsControl
            && !viewState.isBalancingAtFullCharge
    }

    private func limitLabel(_ label: String, value: String) -> some View {
        Text("\(label)  \(value)")
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(DesignColor.secondaryText)
    }

    private var readoutColor: Color {
        return switch viewState.readout.emphasis {
        case .charging, .balancing: DesignColor.secondaryText
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private var chargingIconColor: Color {
        if let status = viewState.control.status {
            return statusColor(status.emphasis)
        }
        return switch viewState.readout.emphasis {
        case .charging: DesignColor.positive
        case .balancing: colorScheme == .dark ? Color.cyan : Constants.lightBalancingAccent
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private var chargingSystemImage: String {
        viewState.control.status?.systemImage ?? viewState.readout.systemImage
    }

    private var chargingSubtitle: String? {
        viewState.control.status?.text ?? viewState.readout.subtitle
    }

    private var chargingSubtitleColor: Color {
        guard let status = viewState.control.status else { return readoutColor }
        return statusColor(status.emphasis)
    }

    private func statusColor(_ emphasis: ChargingDashboardStatusViewData.Emphasis) -> Color {
        switch emphasis {
        case .power, .general: DesignColor.informational
        case .target: DesignColor.positive
        case .failure: DesignColor.critical
        }
    }

    private var chargingProgressIfVisible: Double? {
        guard viewState.readout.showsProgress, viewState.batteryPercent != nil else { return nil }
        return chargingProgress
    }

    private var chargingProgress: Double {
        guard let batteryPercent = viewState.batteryPercent else { return .zero }
        let target = max(displayedTargetPercent, 1)
        return min(max(Double(batteryPercent) / target, .zero), 1)
    }

    private func formattedPower(_ watts: Double) -> String {
        let kilowatts = watts / Constants.wattsPerKilowatt
        return "\(kilowatts.formatted(.number.precision(.fractionLength(1)))) kW"
    }

    private func formattedPercentage(_ percentage: Double) -> String {
        "\(Int(percentage.rounded()))%"
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
    }

    private struct ControlConfiguration {
        let title: String
        let adjustment: ChargingDashboardAdjustmentViewState
        let tint: Color
        let valueFormatter: (Double) -> String
    }

    private enum Constants {
        static let sectionSpacing: CGFloat = 14
        static let controlSpacing: CGFloat = 4
        static let contentPadding: CGFloat = 20
        static let horizontalInset: CGFloat = 8
        static let verticalInset: CGFloat = 16
        static let cornerRadius: CGFloat = 30
        static let readoutFontSize: CGFloat = 32
        static let readoutMinimumScaleFactor = 0.7
        static let disabledOpacity = 0.55
        static let wattsPerKilowatt = 1_000.0
        static let lightBalancingAccent = Color(red: 0, green: 0.66, blue: 0.86)
        static let statusAnimationDuration = 0.18
    }
}
