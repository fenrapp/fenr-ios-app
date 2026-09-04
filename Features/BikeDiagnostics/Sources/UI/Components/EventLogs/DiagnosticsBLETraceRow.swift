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
        .padding(.vertical, Constants.verticalPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var metadataSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                metadataItem(session.duration, systemImage: "timer")
                metadataItem(session.size, systemImage: "externaldrive")
                metadataItem(session.eventCount, systemImage: "waveform.path.ecg")
            }
        } else {
            HStack(spacing: DesignSpace.small) {
                metadataItem(session.duration, systemImage: "timer")
                metadataItem(session.eventCount, systemImage: "waveform.path.ecg")
            }
        }
    }

    private func metadataItem(_ text: String, systemImage: String) -> some View {
        HStack(spacing: Constants.metadataSpacing) {
            Text(text)
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, Constants.metadataHorizontalPadding)
        .padding(.vertical, Constants.metadataVerticalPadding)
        .background(.secondary.opacity(Constants.metadataBackgroundOpacity), in: Capsule())
        .fixedSize()
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
        static let textSpacing: CGFloat = 4
        static let summaryTopPadding: CGFloat = 4
        static let minimumHeight: CGFloat = 68
        static let verticalPadding: CGFloat = 4
        static let metadataSpacing: CGFloat = 4
        static let metadataHorizontalPadding: CGFloat = 7
        static let metadataVerticalPadding: CGFloat = 3
        static let metadataBackgroundOpacity = 0.08
    }
}
