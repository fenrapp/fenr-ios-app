import DesignSystem
import SwiftUI

struct PowerModeStatusPanel: View {
    let status: PowerModeStatusViewData
    let canRetry: Bool
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            HStack(alignment: .top, spacing: DesignSpace.small) {
                statusSymbol

                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(status.title)
                        .font(.headline)
                    Text(status.detail)
                        .font(.subheadline)
                        .foregroundStyle(DesignColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }

            if canRetry {
                Button(.powerModeSettingsRetry, action: retry)
                    .font(.callout.weight(.semibold))
                    .frame(minHeight: Constants.minimumControlSize)
            }
        }
    }

    @ViewBuilder private var statusSymbol: some View {
        if status.isActivity {
            ProgressView()
                .controlSize(.regular)
                .frame(width: Constants.minimumControlSize, height: Constants.minimumControlSize)
                .accessibilityHidden(true)
        } else {
            Image(systemName: status.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: Constants.minimumControlSize, height: Constants.minimumControlSize)
                .accessibilityHidden(true)
        }
    }

    private var statusColor: Color {
        switch status.emphasis {
        case .neutral: DesignColor.secondaryText
        case .informational: DesignColor.informational
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }

    private enum Constants {
        static let minimumControlSize: CGFloat = 44
    }
}
