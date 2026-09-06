import Charts
import DesignSystem
import SwiftUI

struct DashboardEfficiencyLiveCard: View {
    let state: DashboardEfficiencyViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                header
                powerLegend
                powerChart
                hero
                energySummary
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rideDashboardLocalized(
            .rideDashboardEfficiencyLiveAccessibility(state.valueText, state.unitText, state.status.text)
        ))
    }

    private var header: some View {
        DashboardTripCardHeader(title: rideDashboardLocalized(.rideDashboardEfficiencyLiveTitle)) {
            Text(.rideDashboardEfficiencyWindow)
                .font(.caption2)
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private var hero: some View {
        HStack(alignment: .lastTextBaseline, spacing: DesignSpace.extraSmall) {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(.rideDashboardEfficiencyAverage)
                    .font(.caption2)
                    .foregroundStyle(DesignColor.secondaryText)
                Text(verbatim: state.valueText)
                    .font(.system(size: Constants.heroFontSize, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            Text(state.unitText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
            Spacer(minLength: DesignSpace.small)
            Text(state.status.text)
                .font(.caption2.weight(.bold))
                .foregroundStyle(statusColor)
        }
    }

    private var powerChart: some View {
        Chart {
            RuleMark(y: .value(rideDashboardLocalized(.rideDashboardChartZero), 0))
                .foregroundStyle(DesignColor.secondaryText.opacity(Constants.zeroLineOpacity))
                .lineStyle(.init(lineWidth: Constants.gridLineWidth, dash: Constants.zeroLineDash))
            ForEach(state.powerPoints) { point in
                LineMark(
                    x: .value(rideDashboardLocalized(.rideDashboardChartTime), point.date),
                    y: .value(rideDashboardLocalized(.rideDashboardChartUsedPower), point.usedKilowatts),
                    series: .value(
                        rideDashboardLocalized(.rideDashboardChartUsedPower),
                        rideDashboardLocalized(.rideDashboardEfficiencyLegendUsed)
                    )
                )
                .foregroundStyle(DesignColor.informational)
                .lineStyle(.init(lineWidth: Constants.chartLineWidth, lineCap: .round, lineJoin: .round))
            }
            ForEach(state.powerPoints) { point in
                LineMark(
                    x: .value(rideDashboardLocalized(.rideDashboardChartTime), point.date),
                    y: .value(rideDashboardLocalized(.rideDashboardChartRegeneratedPower), point.regenKilowatts),
                    series: .value(
                        rideDashboardLocalized(.rideDashboardChartRegeneratedPower),
                        rideDashboardLocalized(.rideDashboardEfficiencyLegendRegen)
                    )
                )
                .foregroundStyle(DesignColor.positive)
                .lineStyle(.init(lineWidth: Constants.chartLineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: Constants.axisLabelCount)) { _ in
                AxisGridLine().foregroundStyle(DesignColor.border)
                AxisValueLabel().foregroundStyle(DesignColor.secondaryText)
            }
        }
        .chartYScale(domain: chartDomain)
        .frame(maxWidth: .infinity, minHeight: Constants.chartHeight)
        .overlay {
            if state.powerPoints.isEmpty {
                Text(.rideDashboardEfficiencyWaitingPower)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(.rideDashboardEfficiencyChartAccessibility)
        .accessibilityValue(powerAccessibilityValue)
    }

    private var powerLegend: some View {
        HStack(spacing: DesignSpace.medium) {
            powerLegendItem(
                title: rideDashboardLocalized(.rideDashboardEfficiencyLegendUsed),
                color: DesignColor.informational
            )
            powerLegendItem(
                title: rideDashboardLocalized(.rideDashboardEfficiencyLegendRegen),
                color: DesignColor.positive
            )
            Spacer(minLength: DesignSpace.extraSmall)
            Text(.rideDashboardEfficiencyPowerUnit)
                .font(.caption2)
                .foregroundStyle(DesignColor.secondaryText)
        }
        .accessibilityHidden(true)
    }

    private func powerLegendItem(title: String, color: Color) -> some View {
        HStack(spacing: DesignSpace.extraExtraSmall) {
            Capsule()
                .fill(color)
                .frame(width: Constants.legendLineWidth, height: Constants.legendLineHeight)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
    }

    private var energySummary: some View {
        HStack(spacing: DesignSpace.large) {
            energyItem(
                title: rideDashboardLocalized(.rideDashboardEfficiencyLegendUsed),
                value: state.usedEnergyText,
                color: DesignColor.informational
            )
            energyItem(
                title: rideDashboardLocalized(.rideDashboardEfficiencyLegendRecovered),
                value: state.recoveredEnergyText,
                color: DesignColor.positive
            )
        }
    }

    private func energyItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartDomain: ClosedRange<Double> {
        let maximum = state.powerPoints.reduce(0.5) { result, point in
            max(result, max(point.usedKilowatts, point.regenKilowatts))
        }
        return .zero ... (maximum * Constants.chartScalePadding)
    }

    private var powerAccessibilityValue: String {
        guard let latest = state.powerPoints.last else {
            return rideDashboardLocalized(.rideDashboardEfficiencyWaitingPowerAccessibility)
        }
        let used = latest.usedKilowatts.formatted(.number.precision(.fractionLength(1)))
        let regen = latest.regenKilowatts.formatted(.number.precision(.fractionLength(1)))
        return rideDashboardLocalized(.rideDashboardEfficiencyPowerAccessibility(used, regen))
    }

    private var statusColor: Color {
        switch state.status {
        case .calculated: DesignColor.positive
        case .partial: DesignColor.warning
        case .calculating: DesignColor.secondaryText
        case .netRecovery: DesignColor.positive
        }
    }

    private enum Constants {
        static let heroFontSize: CGFloat = 34
        static let chartHeight: CGFloat = 108
        static let axisLabelCount = 3
        static let chartLineWidth: CGFloat = 2
        static let gridLineWidth: CGFloat = 1
        static let zeroLineDash: [CGFloat] = [3, 3]
        static let zeroLineOpacity = 0.45
        static let chartScalePadding = 1.12
        static let legendLineWidth: CGFloat = 16
        static let legendLineHeight: CGFloat = 3
    }
}
