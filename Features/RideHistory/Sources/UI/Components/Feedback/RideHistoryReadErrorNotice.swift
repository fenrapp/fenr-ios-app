import DesignSystem
import SwiftUI

struct RideHistoryReadErrorNotice: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.small) {
            Label {
                Text(verbatim: message)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .foregroundStyle(DesignColor.critical)
            Button(.rideHistoryRetry, action: retry)
                .accessibilityIdentifier("rideHistory.retry")
        }
    }
}
