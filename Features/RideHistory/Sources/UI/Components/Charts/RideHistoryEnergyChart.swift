import Charts
import DesignSystem
import SwiftUI

struct RideHistoryEnergyChart: View {
    let state: RideHistoryDetailViewState

    @State private var selection = ChartSelection.battery

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            if availableSelections.count > 1 {
                Picker("Energy chart", selection: selectionBinding) {
                    ForEach(availableSelections) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            chart
                .frame(height: Constants.chartHeight)
        }
    }

    @ViewBuilder
    private var chart: some View {
        switch effectiveSelection {
        case .battery:
            Chart(state.batteryPoints) { point in
                AreaMark(
                    x: .value("Distance", point.distance),
                    y: .value("Battery", point.value)
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
                    x: .value("Distance", point.distance),
                    y: .value("Battery", point.value)
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
                            Text("\(percentage)%")
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
            .chartYAxisLabel("Battery (%)")
            .chartXAxisLabel("Distance (\(state.distanceUnit))")
            .accessibilityLabel("Battery level over ride distance")
        case .efficiency:
            Chart(state.efficiencyPoints) { point in
                BarMark(
                    x: .value("Distance", point.distance),
                    y: .value("Efficiency", point.value)
                )
                .foregroundStyle(point.value >= .zero ? DesignColor.informational : DesignColor.positive)
                .cornerRadius(Constants.barRadius)
            }
            .chartYAxisLabel(state.efficiencyUnit)
            .chartXAxisLabel("Distance (\(state.distanceUnit))")
            .accessibilityLabel("Energy efficiency over ride distance")
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

    private enum ChartSelection: String, Identifiable {
        case battery
        case efficiency

        var id: Self { self }
        var title: String {
            switch self {
            case .battery: "Battery"
            case .efficiency: "Efficiency"
            }
        }
    }

    private enum Constants {
        static let chartHeight: CGFloat = 200
        static let lineWidth: CGFloat = 2.5
        static let areaOpacity = 0.18
        static let barRadius: CGFloat = 3
    }
}
