import DesignSystem
import SwiftUI

struct MetricsGridView: View {
    let title: String
    let metrics: [BikeDiagnosticsMetricViewData]

    init(
        title: String = BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionTelemetry),
        metrics: [BikeDiagnosticsMetricViewData]
    ) {
        self.title = title
        self.metrics = metrics
    }

    private let columns = [
        GridItem(.adaptive(minimum: Constants.minimumColumnWidth), spacing: Constants.gridSpacing)
    ]

    var body: some View {
        SurfacePanel(title: title) {
            if metrics.isEmpty {
                Text(.bikeDiagnosticsWaitingForTelemetry)
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
