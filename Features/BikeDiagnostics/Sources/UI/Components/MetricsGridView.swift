import DesignSystem
import SwiftUI

struct MetricsGridView: View {
    let metrics: [BikeDiagnosticsMetricViewData]

    private let columns = [
        GridItem(.adaptive(minimum: Constants.minimumColumnWidth), spacing: Constants.gridSpacing)
    ]

    var body: some View {
        SurfacePanel(title: "Telemetry") {
            if metrics.isEmpty {
                Text("Waiting for telemetry")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
                    ForEach(metrics) { metric in
                        MetricTile(title: metric.title, value: metric.value)
                    }
                }
            }
        }
    }

    private enum Constants {
        static let minimumColumnWidth: CGFloat = 124
        static let gridSpacing = DesignSpace.extraSmall
    }
}

#Preview("Metrics") {
    MetricsGridView(metrics: [
        .init(id: "battery", title: "Battery", value: "91%"),
        .init(id: "mode", title: "Mode", value: "3"),
        .init(id: "speed", title: "Speed", value: "42.1 km/h")
    ])
    .padding()
}
