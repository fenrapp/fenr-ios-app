import SwiftUI

struct BatteryHealthMetricRows: View {
    let metrics: [BatteryHealthMetricViewData]

    var body: some View {
        ForEach(metrics) { metric in
            LabeledContent(metric.title) {
                Text(metric.value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
