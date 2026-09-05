import SwiftUI

struct DiagnosticsMetricRow: View {
    let metric: BikeDiagnosticsMetricViewData

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: Constants.spacing) {
                Text(metric.value)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
                if metric.verification != .confirmed {
                    Text(metric.verification.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text(metric.title)
        }
        .accessibilityElement(children: .combine)
    }

    private enum Constants {
        static let spacing: CGFloat = 2
    }
}
