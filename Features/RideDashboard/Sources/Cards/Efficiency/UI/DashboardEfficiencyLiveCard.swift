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
                powerChart
                energySummary
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live efficiency, \(state.valueText) \(state.unitText), \(state.status.rawValue)")
    }

    private var header: some View {
        DashboardTripCardHeader(title: "EFFICIENCY · LIVE")
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
            Text(state.status.rawValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(statusColor)
        }
    }

    private var powerChart: some View {
        Chart {
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(DesignColor.secondaryText.opacity(0.45))
                .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
            ForEach(state.powerPoints) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Power", point.kilowatts)
                )
                .foregroundStyle(
                    point.kilowatts >= .zero
                        ? DesignColor.informational.opacity(0.18)
                        : DesignColor.positive.opacity(0.2)
                )
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Power", point.kilowatts)
                )
                .foregroundStyle(point.kilowatts >= .zero ? DesignColor.informational : DesignColor.positive)
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: chartDomain)
        .frame(maxWidth: .infinity, minHeight: Constants.chartHeight)
        .overlay {
            if state.powerPoints.isEmpty {
                Text("WAITING FOR POWER DATA")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
        .accessibilityLabel("Electrical power over the last 60 seconds")
    }

    private var energySummary: some View {
        HStack(spacing: DesignSpace.large) {
            energyItem(title: "USED", value: state.usedEnergyText, color: DesignColor.informational)
            energyItem(title: "RECOVERED", value: state.recoveredEnergyText, color: DesignColor.positive)
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
        let values = state.powerPoints.map(\.kilowatts)
        let lower = min(values.min() ?? -1, -0.5)
        let upper = max(values.max() ?? 1, 0.5)
        let padding = max((upper - lower) * 0.12, 0.25)
        return (lower - padding) ... (upper + padding)
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
    }
}
