import SwiftUI

struct DiagnosticsPowerTierEvidenceView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let metrics: [BikeDiagnosticsMetricViewData]

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Constants.spacing) {
                        tierSummary
                    }
                } else {
                    HStack(alignment: .top, spacing: Constants.spacing) {
                        tierSummary
                    }
                }
            }

            if let evidence {
                Divider()
                VStack(alignment: .leading, spacing: Constants.metricSpacing) {
                    Label(evidence.title, systemImage: "checkmark.seal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(evidence.value)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, Constants.verticalPadding)
    }

    @ViewBuilder private var tierSummary: some View {
        ForEach(tiers) { metric in
            VStack(alignment: .leading, spacing: Constants.metricSpacing) {
                Text(metric.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(metric.value)
                    .font(.headline)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tiers: [BikeDiagnosticsMetricViewData] {
        metrics.filter { $0.id != Constants.evidenceID }
    }

    private var evidence: BikeDiagnosticsMetricViewData? {
        metrics.first { $0.id == Constants.evidenceID }
    }

    private enum Constants {
        static let evidenceID = "powerTierEvidence"
        static let spacing: CGFloat = 12
        static let metricSpacing: CGFloat = 3
        static let verticalPadding: CGFloat = 4
    }
}
