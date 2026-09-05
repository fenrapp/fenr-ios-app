import DesignSystem
import SwiftUI

struct DashboardChargingCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewState: ChargingDashboardViewState
    let setPowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void

    @State private var progressTargetPercent: Double
    @State private var selectionFeedbackTrigger = 0

    init(
        viewState: ChargingDashboardViewState,
        setPowerLimit: @escaping (Double) -> Void,
        setChargeTarget: @escaping (Double) -> Void
    ) {
        self.viewState = viewState
        self.setPowerLimit = setPowerLimit
        self.setChargeTarget = setChargeTarget
        _progressTargetPercent = State(initialValue: viewState.control.target.selected)
    }

    var body: some View {
        VStack(spacing: Constants.sectionSpacing) {
            chargingStatus
            chargeControl(
                configuration: .init(
                    title: rideDashboardLocalized(.rideDashboardChargingMaximumPower),
                    adjustment: viewState.control.power,
                    tint: DesignColor.informational,
                    valueFormatter: formattedPower
                ),
                commit: setPowerLimit
            )
            .accessibilityIdentifier("dashboard.charging.power")
            chargeControl(
                configuration: .init(
                    title: rideDashboardLocalized(.rideDashboardChargingChargeLimit),
                    adjustment: viewState.control.target,
                    tint: DesignColor.positive,
                    valueFormatter: formattedPercentage
                ),
                commit: { value in
                    progressTargetPercent = value
                    setChargeTarget(value)
                }
            )
            .accessibilityIdentifier("dashboard.charging.target")
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
        .onChange(of: viewState.control.target.selected) { _, value in
            progressTargetPercent = value
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
        commit: @escaping (Double) -> Void
    ) -> some View {
        let isEnabled = controlIsEnabled(configuration.adjustment)
        return CommitSlider(
            value: configuration.adjustment.selected,
            in: configuration.adjustment.minimum ... configuration.adjustment.maximum,
            step: configuration.adjustment.step,
            tint: configuration.tint,
            isEnabled: isEnabled,
            onCommit: { value in
                selectionFeedbackTrigger += 1
                commit(value)
            },
            header: { value in
                HStack(alignment: .firstTextBaseline) {
                    Text(configuration.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DesignColor.secondaryText)
                    Spacer()
                    Text(configuration.valueFormatter(value))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(DesignColor.primaryText)
                }
            },
            footer: {
                HStack {
                    limitLabel(
                        rideDashboardLocalized(.rideDashboardCommonMinimum),
                        value: configuration.valueFormatter(configuration.adjustment.minimum)
                    )
                    Spacer()
                    limitLabel(
                        rideDashboardLocalized(.rideDashboardCommonMaximum),
                        value: configuration.valueFormatter(configuration.adjustment.maximum)
                    )
                }
            }
        )
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
        Text(verbatim: "\(label)  \(value)")
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
        case .balancing: colorScheme == .dark ? Color.cyan : DashboardSemanticColor.lightBalancing
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
        let target = max(progressTargetPercent, 1)
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
        static let contentPadding: CGFloat = 20
        static let horizontalInset: CGFloat = 8
        static let verticalInset: CGFloat = 16
        static let cornerRadius: CGFloat = 30
        static let readoutFontSize: CGFloat = 32
        static let readoutMinimumScaleFactor = 0.7
        static let disabledOpacity = 0.55
        static let wattsPerKilowatt = 1_000.0
        static let statusAnimationDuration = 0.18
    }
}
