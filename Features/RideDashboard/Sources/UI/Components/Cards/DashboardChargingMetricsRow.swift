import DesignSystem
import SwiftUI

struct DashboardChargingMetricsRow: View {
    let power: DashboardMetricViewData
    let current: DashboardMetricViewData
    let temperature: DashboardMetricViewData
    let temperatureEmphasis: ChargingDashboardViewState.TemperatureEmphasis
    let activeBalancingCells: DashboardMetricViewData?

    var body: some View {
        HStack(spacing: .zero) {
            metric(title: "INPUT", data: power)
            divider
            metric(title: "CURRENT", data: current)
            divider
            metric(title: "TEMP", data: temperature, valueColor: temperatureColor)
            if let activeBalancingCells {
                divider
                metric(title: "CELLS", data: activeBalancingCells)
            }
        }
        .padding(.top, Constants.topPadding)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignColor.border)
                .frame(height: Constants.separatorWidth)
        }
        .accessibilityElement(children: .contain)
    }

    private func metric(
        title: String,
        data: DashboardMetricViewData,
        valueColor: Color = DesignColor.primaryText
    ) -> some View {
        VStack(spacing: Constants.metricSpacing) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
                Text(data.valueText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                if let unit = data.unitText {
                    Text(unit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(DesignColor.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(Constants.minimumScaleFactor)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColor.border)
            .frame(width: Constants.separatorWidth, height: Constants.dividerHeight)
    }

    private var temperatureColor: Color {
        switch temperatureEmphasis {
        case .unavailable: DesignColor.secondaryText
        case .normal: DesignColor.primaryText
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private enum Constants {
        static let topPadding: CGFloat = 10
        static let metricSpacing: CGFloat = 2
        static let separatorWidth: CGFloat = 1
        static let dividerHeight: CGFloat = 34
        static let minimumScaleFactor = 0.75
    }
}
