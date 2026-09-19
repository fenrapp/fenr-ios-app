import SwiftUI

struct OfflineRouteActions: View {
    let onDownloadMap: (() -> Void)?
    let onFollowGPX: (() -> Void)?

    var body: some View {
        if let onDownloadMap {
            Button(action: onDownloadMap) { Label(.offlineDownloadRoute, systemImage: "arrow.down.circle") }
        }
        if let onFollowGPX {
            Button(action: onFollowGPX) {
                Label(.offlineFollowGPX, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .accessibilityHint(.offlineFollowGPXExplanation)
        }
    }
}
