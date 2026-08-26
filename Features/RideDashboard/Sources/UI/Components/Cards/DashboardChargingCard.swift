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
        .onChange(of: viewState.control.power.selected) { value in
            guard !isEditingPower else { return }
            displayedPowerWatts = value
        }
        .onChange(of: viewState.control.target.selected) { value in
            guard !isEditingTarget else { return }
            displayedTargetPercent = value
        }
        .animation(.easeInOut(duration: Constants.statusAnimationDuration), value: viewState.control.status)
        .accessibilityElement(children: .contain)
    }

    private var chargingStatus: some View {
        HStack(spacing: DesignSpace.medium) {
            ZStack {
                Circle()
                    .fill(chargingIconColor.opacity(Constants.iconBackgroundOpacity))
                Image(systemName: viewState.readout.systemImage)
                    .font(.system(size: Constants.iconSize, weight: .bold))
                    .foregroundStyle(chargingIconColor)
            }
            .frame(width: Constants.iconContainerSize, height: Constants.iconContainerSize)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Constants.readoutSpacing) {
                Text(viewState.readout.title)
                    .font(.system(size: Constants.readoutFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(readoutColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.readoutMinimumScaleFactor)
                if let subtitle = viewState.readout.subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(readoutColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: .zero)

            if let status = viewState.control.status {
                DashboardChargingControlStatusBadge(status: status)
            }
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
        VStack(spacing: Constants.controlSpacing) {
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
                        controlsAreEnabled,
                        value.wrappedValue != configuration.adjustment.selected
                    else { return }
                    commit(value.wrappedValue)
                }
            )
            .tint(configuration.tint)
            .disabled(!controlsAreEnabled)

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
        .opacity(controlsAreEnabled ? 1 : Constants.disabledOpacity)
        .accessibilityElement(children: .contain)
    }

    private var controlsAreEnabled: Bool {
        viewState.control.isEnabled
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
        switch viewState.readout.emphasis {
        case .charging, .balancing: DesignColor.secondaryText
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private var chargingIconColor: Color {
        switch viewState.readout.emphasis {
        case .charging: DesignColor.positive
        case .balancing: colorScheme == .dark ? Color.cyan : Constants.lightBalancingAccent
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
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
        static let iconContainerSize: CGFloat = 68
        static let iconSize: CGFloat = 30
        static let iconBackgroundOpacity = 0.14
        static let readoutFontSize: CGFloat = 32
        static let readoutSpacing: CGFloat = 1
        static let readoutMinimumScaleFactor = 0.7
        static let disabledOpacity = 0.55
        static let wattsPerKilowatt = 1_000.0
        static let lightBalancingAccent = Color(red: 0, green: 0.66, blue: 0.86)
        static let statusAnimationDuration = 0.18
    }
}
