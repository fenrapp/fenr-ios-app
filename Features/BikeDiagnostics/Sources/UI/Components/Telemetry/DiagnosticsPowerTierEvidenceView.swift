import DesignSystem
import SwiftUI

struct DiagnosticsPowerTierEvidenceView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let metrics: [BikeDiagnosticsMetricViewData]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DesignSpace.small) {
                        tierSummary
                    }
                } else {
                    HStack(alignment: .top, spacing: DesignSpace.small) {
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
        .padding(.vertical, DesignSpace.extraExtraSmall)
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
        static let metricSpacing: CGFloat = 3
    }
}
