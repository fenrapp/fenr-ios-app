import Charts
import DesignSystem
import SwiftUI

struct DashboardEfficiencyLiveCard: View {
    let state: DashboardEfficiencyViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(alignment: .leading, spacing: Constants.spacing) {
                header
                hero
                powerLegend
                powerChart
                energySummary
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rideDashboardLocalized(
            .rideDashboardEfficiencyLiveAccessibility(state.valueText, state.unitText, state.status.text)
        ))
    }

    private var header: some View {
        DashboardTripCardHeader(title: rideDashboardLocalized(.rideDashboardEfficiencyLiveTitle))
    }

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraSmall) {
            Text(state.valueText)
                .font(.system(size: Constants.heroFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
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
                .foregroundStyle(DesignColor.secondaryText.opacity(0.45))
                .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
            ForEach(state.powerPoints) { point in
                AreaMark(
                    x: .value(rideDashboardLocalized(.rideDashboardChartTime), point.date),
                    y: .value(rideDashboardLocalized(.rideDashboardChartUsedPower), point.usedKilowatts)
                )
                .foregroundStyle(DesignColor.informational.opacity(0.18))
                LineMark(
                    x: .value(rideDashboardLocalized(.rideDashboardChartTime), point.date),
                    y: .value(rideDashboardLocalized(.rideDashboardChartUsedPower), point.usedKilowatts)
                )
                .foregroundStyle(DesignColor.informational)
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            ForEach(state.powerPoints) { point in
                AreaMark(
                    x: .value(rideDashboardLocalized(.rideDashboardChartTime), point.date),
                    y: .value(rideDashboardLocalized(.rideDashboardChartRegeneratedPower), point.regenKilowatts)
                )
                .foregroundStyle(DesignColor.positive.opacity(0.2))
                LineMark(
                    x: .value(rideDashboardLocalized(.rideDashboardChartTime), point.date),
                    y: .value(rideDashboardLocalized(.rideDashboardChartRegeneratedPower), point.regenKilowatts)
                )
                .foregroundStyle(DesignColor.positive)
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
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
        static let spacing: CGFloat = 8
        static let heroFontSize: CGFloat = 40
        static let chartHeight: CGFloat = 118
        static let chartScalePadding = 1.12
        static let legendLineWidth: CGFloat = 16
        static let legendLineHeight: CGFloat = 3
    }
}
