import DesignSystem
import SwiftUI

struct BatteryHealthMetricsGridView: View {
    let metrics: [BatteryHealthMetricViewData]

    private let columns = [
        GridItem(.adaptive(minimum: Constants.minimumColumnWidth), spacing: Constants.gridSpacing)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
            ForEach(metrics) { metric in
                MetricTile(title: metric.title, value: metric.value)
            }
        }
    }

    private enum Constants {
        static let minimumColumnWidth: CGFloat = 132
        static let gridSpacing = DesignSpace.extraSmall
    }
}

#Preview("Battery Health metrics") {
    BatteryHealthMetricsGridView(metrics: [
        .init(id: "soc", title: "SOC", value: "76%"),
        .init(id: "dcBus", title: "DC bus", value: "394.8 V")
    ])
    .padding()
}
