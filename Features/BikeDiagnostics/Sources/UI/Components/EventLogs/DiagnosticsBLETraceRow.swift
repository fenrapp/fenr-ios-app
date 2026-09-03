import DesignSystem
import SwiftUI

struct DiagnosticsBLETraceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let session: BLETraceSessionViewData

    var body: some View {
        HStack(alignment: .top, spacing: DesignSpace.small) {
            ListRowIcon(systemImage: statusSymbol, tint: statusTint)

            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                Text(session.status)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(session.date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                metadataSummary
                    .padding(.top, Constants.summaryTopPadding)
            }

            Spacer(minLength: DesignSpace.extraSmall)

            if !dynamicTypeSize.isAccessibilitySize {
                Text(session.size)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Constants.minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var metadataSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                summaryLabel(session.duration, systemImage: "timer")
                summaryLabel(session.size, systemImage: "externaldrive")
                summaryLabel(session.eventCount, systemImage: "waveform.path.ecg")
            }
        } else {
            HStack(spacing: DesignSpace.small) {
                summaryLabel(session.duration, systemImage: "timer")
                summaryLabel(session.eventCount, systemImage: "waveform.path.ecg")
            }
        }
    }

    private func summaryLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private var statusSymbol: String {
        switch session.statusKind {
        case .recording: "record.circle.fill"
        case .complete: "checkmark.circle.fill"
        case .incomplete: "exclamationmark.circle.fill"
        case .truncated: "exclamationmark.triangle.fill"
        }
    }

    private var statusTint: Color {
        switch session.statusKind {
        case .recording: DesignColor.critical
        case .complete: DesignColor.positive
        case .incomplete: DesignColor.warning
        case .truncated: DesignColor.critical
        }
    }

    private enum Constants {
        static let textSpacing: CGFloat = 2
        static let summaryTopPadding: CGFloat = 2
        static let minimumHeight: CGFloat = 60
    }
}
