import DesignSystem
import SwiftUI

struct RideNavigationOfflineMapsAction: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSpace.small) {
                Image(systemName: "map")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignColor.accent)
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(.offlineMapsTitle).font(.headline)
                    Text(.offlineManageDownloads).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(DesignSpace.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignColor.groupedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
            .contentShape(RoundedRectangle(cornerRadius: DesignRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rideNavigation.offlineMaps")
    }
}
