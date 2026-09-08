import DesignSystem
import SwiftUI

struct DashboardHistoryReadFeedback: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(DesignColor.warning)
            Button(.rideDashboardHistoryRetry, action: retry)
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("dashboard.history.retry")
        }
        .accessibilityIdentifier("dashboard.history.error")
    }
}
