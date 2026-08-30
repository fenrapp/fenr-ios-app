import DesignSystem
import SwiftUI

struct DashboardBikeLockStatusBadge: View {
    var body: some View {
        Label("BIKE LOCKED", systemImage: "lock.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(DesignColor.warning)
            .padding(.horizontal, DesignSpace.medium)
            .frame(minHeight: Constants.minimumHeight)
            .background(
                DesignColor.warning.opacity(Constants.backgroundOpacity),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        DesignColor.warning.opacity(Constants.borderOpacity),
                        lineWidth: Constants.borderWidth
                    )
            }
            .accessibilityLabel("Bike locked")
    }

    private enum Constants {
        static let minimumHeight: CGFloat = 36
        static let backgroundOpacity = 0.14
        static let borderOpacity = 0.4
        static let borderWidth: CGFloat = 1
    }
}
