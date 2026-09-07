import DesignSystem
import SwiftUI

struct MaintenanceReadErrorNotice: View {
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
            Button(.maintenanceRetry, action: retry)
                .accessibilityIdentifier("maintenance.retry")
        }
    }
}
