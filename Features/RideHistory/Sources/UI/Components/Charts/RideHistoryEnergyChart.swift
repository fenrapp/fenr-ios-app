import Charts
import DesignSystem
import SwiftUI

struct RideHistoryEnergyChart: View {
    let state: RideHistoryDetailViewState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection = ChartSelection.battery

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            if availableSelections.count > 1 {
                Picker(.rideHistoryEnergyChart, selection: selectionBinding) {
                    ForEach(availableSelections) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            chart
                .frame(height: chartHeight)
        }
    }

    @ViewBuilder
    private var chart: some View {
        switch effectiveSelection {
        case .battery:
            Chart(state.batteryPoints) { point in
                AreaMark(
                    x: .value(String(localized: .rideHistoryMetricDistance), point.distance),
                    y: .value(String(localized: .rideHistoryMetricBattery), point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            DesignColor.positive.opacity(Constants.areaOpacity),
                            DesignColor.positive.opacity(.zero)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value(String(localized: .rideHistoryMetricDistance), point.distance),
                    y: .value(String(localized: .rideHistoryMetricBattery), point.value)
                )
                .foregroundStyle(DesignColor.positive)
                .lineStyle(.init(lineWidth: Constants.lineWidth, lineCap: .round, lineJoin: .round))
            }
            .chartYScale(domain: 0 ... 100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let percentage = value.as(Int.self) {
                            Text(verbatim: "\(percentage)%")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) {
                    AxisGridLine().foregroundStyle(.clear)
                    AxisValueLabel()
                }
            }
            .chartYAxisLabel(String(localized: .rideHistoryChartBatteryAxis))
            .chartXAxisLabel(String(localized: .rideHistoryChartDistanceAxis(state.distanceUnit)))
            .accessibilityLabel(.rideHistoryChartBatteryAccessibility)
        case .efficiency:
            Chart(state.efficiencyPoints) { point in
                BarMark(
                    x: .value(String(localized: .rideHistoryMetricDistance), point.distance),
                    y: .value(String(localized: .rideHistoryMetricEfficiency), point.value)
                )
                .foregroundStyle(point.value >= .zero ? DesignColor.informational : DesignColor.positive)
                .cornerRadius(Constants.barRadius)
            }
            .chartYAxisLabel(state.efficiencyUnit)
            .chartXAxisLabel(String(localized: .rideHistoryChartDistanceAxis(state.distanceUnit)))
            .accessibilityLabel(.rideHistoryChartEfficiencyAccessibility)
        }
    }

    private var availableSelections: [ChartSelection] {
        var result: [ChartSelection] = []
        if !state.batteryPoints.isEmpty { result.append(.battery) }
        if !state.efficiencyPoints.isEmpty { result.append(.efficiency) }
        return result
    }

    private var effectiveSelection: ChartSelection {
        availableSelections.contains(selection) ? selection : availableSelections.first ?? .battery
    }

    private var selectionBinding: Binding<ChartSelection> {
        .init(get: { effectiveSelection }, set: { selection = $0 })
    }

    private var chartHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Constants.accessibilityChartHeight
            : Constants.regularChartHeight
    }

    private enum ChartSelection: String, Identifiable {
        case battery
        case efficiency

        var id: Self { self }
        var title: LocalizedStringResource {
            switch self {
            case .battery: .rideHistoryMetricBattery
            case .efficiency: .rideHistoryMetricEfficiency
            }
        }
    }

    private enum Constants {
        static let regularChartHeight: CGFloat = 200
        static let accessibilityChartHeight: CGFloat = 280
        static let lineWidth: CGFloat = 2.5
        static let areaOpacity = 0.18
        static let barRadius: CGFloat = 3
    }
}
