import Charts
import DesignSystem
import SwiftUI

struct DashboardBatteryTripCard: View {
    let state: DashboardRangeViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(alignment: .leading, spacing: Constants.spacing) {
                DashboardTripCardHeader(title: rideDashboardLocalized(.rideDashboardRangeBatteryTripTitle))
                hero
                batteryChart
                peakSummary
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rideDashboardLocalized(
            .rideDashboardRangeTripAccessibility(state.batteryText, state.remainingEnergyText)
        ))
    }

    private var hero: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(state.batteryText)
                .font(.system(size: Constants.heroFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
            Spacer(minLength: DesignSpace.medium)
            VStack(alignment: .trailing, spacing: DesignSpace.extraExtraSmall) {
                Text(.rideDashboardRangeEnergyLeft)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DesignColor.secondaryText)
                Text(state.remainingEnergyText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
    }

    private var batteryChart: some View {
        Chart {
            ForEach(state.batteryPoints) { point in
                AreaMark(
                    x: .value(rideDashboardLocalized(.rideDashboardChartDistance), point.distance),
                    y: .value(rideDashboardLocalized(.rideDashboardChartBattery), point.percentage)
                )
                .foregroundStyle(DesignColor.positive.opacity(0.16))
                LineMark(
                    x: .value(rideDashboardLocalized(.rideDashboardChartDistance), point.distance),
                    y: .value(rideDashboardLocalized(.rideDashboardChartBattery), point.percentage)
                )
                .foregroundStyle(DesignColor.positive)
                .lineStyle(.init(lineWidth: 2.25, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0 ... 100)
        .frame(maxWidth: .infinity, minHeight: Constants.chartHeight)
        .overlay {
            if state.batteryPoints.isEmpty {
                Text(.rideDashboardRangeWaitingTrip)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
        .accessibilityLabel(.rideDashboardRangeTripChartAccessibility)
    }

    private var peakSummary: some View {
        HStack(spacing: DesignSpace.large) {
            peak(
                title: rideDashboardLocalized(.rideDashboardRangePeakUse),
                value: state.peakDischargeText,
                color: DesignColor.informational
            )
            peak(
                title: rideDashboardLocalized(.rideDashboardRangePeakRegen),
                value: state.peakRegenerationText,
                color: DesignColor.positive
            )
        }
    }

    private func peak(title: String, value: String, color: Color) -> some View {
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

    private enum Constants {
        static let spacing: CGFloat = 8
        static let heroFontSize: CGFloat = 44
        static let chartHeight: CGFloat = 120
    }
}
