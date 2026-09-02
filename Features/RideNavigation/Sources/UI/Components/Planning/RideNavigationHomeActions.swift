import DesignSystem
import SwiftUI

struct RideNavigationHomeActions: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onImport: () -> Void
    let onRecord: () -> Void

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: DesignSpace.small) { actions }
        } else {
            HStack(spacing: DesignSpace.small) { actions }
        }
    }

    private var actions: some View {
        Group {
            RideNavigationQuickAction(
                title: String(localized: .rideNavigationImportGPX),
                subtitle: String(localized: .rideNavigationOpenTrail),
                systemImage: "square.and.arrow.down",
                color: DesignColor.accent,
                action: onImport
            )
            RideNavigationQuickAction(
                title: String(localized: .rideNavigationRecordRide),
                subtitle: String(localized: .rideNavigationTrackAsYouGo),
                systemImage: "record.circle",
                color: DesignColor.critical,
                action: onRecord
            )
        }
    }
}
