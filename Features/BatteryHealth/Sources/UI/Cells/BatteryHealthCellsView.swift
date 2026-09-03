import Charts
import DesignSystem
import SwiftUI

struct BatteryHealthCellsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: BatteryHealthCellsViewData

    @ScaledMetric(relativeTo: .body) private var chartHeight = Constants.chartHeight

    var body: some View {
        List {
            Section(BatteryHealthText.packRange) {
                if state.metrics.isEmpty {
                    ContentUnavailableView(
                        BatteryHealthText.awaitingCellData,
                        systemImage: "battery.0percent",
                        description: Text(BatteryHealthText.awaitingCellDataDetail)
                    )
                } else {
                    BatteryHealthMetricRows(metrics: state.metrics)
                }
            }

            Section(BatteryHealthText.healthDistribution) {
                SegmentedDistributionBar(segments: [
                    .init(value: Double(state.distribution.normalCount), color: DesignColor.positive),
                    .init(value: Double(state.distribution.attentionCount), color: DesignColor.warning),
                    .init(value: Double(state.distribution.criticalCount), color: DesignColor.critical)
                ])
                .accessibilityLabel(distributionAccessibilityLabel)

                LabeledContent(BatteryHealthText.normal, value: state.distribution.normalCount.formatted())
                LabeledContent(BatteryHealthText.attention, value: state.distribution.attentionCount.formatted())
                LabeledContent(BatteryHealthText.critical, value: state.distribution.criticalCount.formatted())
            }

            Section(BatteryHealthText.balancing) {
                LabeledContent(BatteryHealthText.activeCells, value: state.balancingCount.formatted())
                Text(BatteryHealthText.balancingExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(BatteryHealthText.cellDeviation) {
                if state.cells.isEmpty {
                    Text(BatteryHealthText.noDecodedCells)
                        .foregroundStyle(.secondary)
                } else {
                    deviationChart
                    ForEach(state.cells) { cell in
                        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                            cellHeader(cell)
                            HStack {
                                ProgressView(value: cell.deviationProgress)
                                    .tint(color(for: cell.condition))
                                Text(cell.deviation)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, DesignSpace.extraExtraSmall)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(cellAccessibilityLabel(cell))
                    }
                }
            }
        }
    }

    private var deviationChart: some View {
        Chart(state.cells) { cell in
            BarMark(
                x: .value(String(localized: .batteryHealthChartCell), cell.position),
                yStart: .value(String(localized: .batteryHealthChartBaseline), 0),
                yEnd: .value(String(localized: .batteryHealthChartDeviation), cell.deviationMillivolts)
            )
            .foregroundStyle(color(for: cell.condition))
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let millivolts = value.as(Double.self) {
                        Text(verbatim: "\(millivolts.formatted(.number.precision(.fractionLength(0)))) mV")
                    }
                }
            }
        }
        .frame(minHeight: chartHeight)
        .accessibilityLabel(Text(verbatim: BatteryHealthText.cellDeviationAccessibility))
    }

    private var distributionAccessibilityLabel: String {
        BatteryHealthText.cellDistributionAccessibility(
            normal: state.distribution.normalCount,
            attention: state.distribution.attentionCount,
            critical: state.distribution.criticalCount
        )
    }

    @ViewBuilder
    private func cellHeader(_ cell: BatteryCellViewData) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(BatteryHealthText.cellPosition(cell.position))
                cellBadges(cell)
                Text(cell.voltage)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        } else {
            HStack {
                Text(BatteryHealthText.cellPosition(cell.position))
                cellBadges(cell)
                Spacer()
                Text(cell.voltage)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func cellBadges(_ cell: BatteryCellViewData) -> some View {
        if cell.condition != .normal {
            Text(conditionText(cell.condition))
                .badgeStyle(color: color(for: cell.condition))
        }
        if cell.isMinimum { Text(BatteryHealthText.minimum).badgeStyle() }
        if cell.isMaximum { Text(BatteryHealthText.maximum).badgeStyle() }
        if cell.isBalancing { Text(BatteryHealthText.balancing).badgeStyle() }
    }

    private func cellAccessibilityLabel(_ cell: BatteryCellViewData) -> String {
        [
            BatteryHealthText.cellPosition(cell.position),
            conditionText(cell.condition),
            cell.voltage,
            cell.deviation,
            cell.isBalancing ? BatteryHealthText.balancing : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private func conditionText(_ condition: BatteryCellCondition) -> String {
        switch condition {
        case .normal: BatteryHealthText.normal
        case .belowAverage: BatteryHealthText.belowAverage
        case .aboveAverage: BatteryHealthText.aboveAverage
        case .critical: BatteryHealthText.critical
        }
    }

    private func color(for condition: BatteryCellCondition) -> Color {
        switch condition {
        case .normal: DesignColor.positive
        case .belowAverage, .aboveAverage: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private enum Constants {
        static let chartHeight: CGFloat = 180
    }
}

private extension View {
    func badgeStyle(color: Color = .secondary) -> some View {
        font(.caption2)
            .foregroundStyle(color)
    }
}
