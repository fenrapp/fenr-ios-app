import Charts
import DesignSystem
import SwiftUI

struct DashboardRangeLiveCard: View {
    let state: DashboardRangeViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(alignment: .leading, spacing: Constants.spacing) {
                DashboardTripCardHeader(title: "RANGE · LIVE")
                hero
                consumptionChart
                rangeComparison
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Estimated range, \(state.rangeText) \(state.distanceUnitText), \(state.status.rawValue)")
    }

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraSmall) {
            Text(state.rangeText)
                .font(.system(size: Constants.heroFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
            Text(state.distanceUnitText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
            Spacer(minLength: DesignSpace.small)
            Text(state.isLoadingHistory ? "LOADING" : state.status.rawValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(statusColor)
        }
    }

    private var consumptionChart: some View {
        Chart {
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(DesignColor.secondaryText.opacity(0.35))
            if let typicalEfficiency = state.typicalEfficiency {
                RuleMark(y: .value("Typical", typicalEfficiency))
                    .foregroundStyle(DesignColor.secondaryText.opacity(0.65))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 3]))
            }
            ForEach(state.consumptionPoints) { point in
                AreaMark(
                    x: .value("Distance", point.distance),
                    y: .value("Efficiency", point.efficiency)
                )
                .foregroundStyle(point.efficiency >= .zero
                    ? DesignColor.informational.opacity(0.2)
                    : DesignColor.positive.opacity(0.22))
                LineMark(
                    x: .value("Distance", point.distance),
                    y: .value("Efficiency", point.efficiency)
                )
                .foregroundStyle(point.efficiency >= .zero ? DesignColor.informational : DesignColor.positive)
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: chartDomain)
        .frame(maxWidth: .infinity, minHeight: Constants.chartHeight)
        .overlay {
            if state.consumptionPoints.isEmpty {
                Text("LEARNING YOUR CONSUMPTION")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
        .accessibilityLabel("Energy consumption over the latest distance")
    }

    private var rangeComparison: some View {
        HStack(spacing: DesignSpace.large) {
            comparison(title: "TYPICAL", value: state.typicalRangeText)
            comparison(title: "CURRENT PACE", value: state.currentRangeText)
        }
    }

    private func comparison(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
            Text("\(value) \(state.distanceUnitText)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartDomain: ClosedRange<Double> {
        let values = state.consumptionPoints.map(\.efficiency) + [state.typicalEfficiency].compactMap { $0 }
        let lower = min(values.min() ?? .zero, .zero)
        let upper = max(values.max() ?? 100, 100)
        let padding = max((upper - lower) * 0.12, 10)
        return (lower - padding) ... (upper + padding)
    }

    private var statusColor: Color {
        switch state.status {
        case .learning: DesignColor.secondaryText
        case .adapting: DesignColor.warning
        case .stable: DesignColor.positive
        }
    }

    private enum Constants {
        static let spacing: CGFloat = 8
        static let heroFontSize: CGFloat = 48
        static let chartHeight: CGFloat = 112
    }
}
