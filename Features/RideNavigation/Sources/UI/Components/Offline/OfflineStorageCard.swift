import DesignSystem
import SwiftUI

struct OfflineStorageCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let used: String
    let free: String
    let wifiOnly: Bool
    let onWiFiOnly: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.medium) {
            Label(.offlineOnThisPhone, systemImage: "iphone.gen3")
                .font(.subheadline.weight(.semibold))
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignSpace.medium) {
                    usedStorage
                    freeStorage(alignment: .leading)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DesignSpace.large) {
                    usedStorage
                    Spacer(minLength: DesignSpace.small)
                    freeStorage(alignment: .trailing)
                }
            }
            Divider().opacity(Constants.dividerOpacity)
            Toggle(isOn: Binding(get: { wifiOnly }, set: { onWiFiOnly($0) })) {
                Label(.offlineWiFiOnly, systemImage: "wifi").font(.subheadline)
            }
            .tint(DesignColor.accent)
        }
        .padding(DesignSpace.large)
        .rideNavigationGlassSurface(cornerRadius: Constants.radius)
    }

    private var usedStorage: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(verbatim: used).font(.system(.title2, design: .rounded, weight: .bold))
            Text(.offlineStorageUsed).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func freeStorage(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: DesignSpace.extraExtraSmall) {
            Text(verbatim: free).font(.subheadline.weight(.medium))
            Text(.offlineStorageFree).font(.caption).foregroundStyle(.secondary)
        }
    }

    private enum Constants {
        static let radius = 28.0
        static let dividerOpacity = 0.6
    }
}
