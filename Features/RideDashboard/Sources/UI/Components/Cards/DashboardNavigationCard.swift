import DesignSystem
import SwiftUI

struct DashboardNavigationCard: View {
    let isNavigationActive: Bool
    let openNavigation: () -> Void

    var body: some View {
        VStack(spacing: DesignSpace.large) {
            VStack(spacing: DesignSpace.medium) {
                Image(systemName: "map.circle.fill")
                    .font(.system(size: Constants.iconSize, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DesignColor.accent)

                VStack(spacing: DesignSpace.extraSmall) {
                    Text("RIDE NAVIGATION")
                        .font(.caption.weight(.semibold))
                        .tracking(Constants.eyebrowTracking)
                        .foregroundStyle(DesignColor.secondaryText)
                    Text(isNavigationActive ? "Navigation is running" : "The trail, front and center")
                        .font(.title2.weight(.bold))
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(DesignColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Constants.descriptionWidth)
            }

            Button(action: openNavigation) {
                HStack {
                    Image(systemName: isNavigationActive ? "arrow.up.left.and.arrow.down.right" : "location.north.fill")
                    Text(isNavigationActive ? "Return to Navigation" : "Open Navigation")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: Constants.buttonWidth)
            .accessibilityIdentifier("dashboard.navigation.open")
        }
        .padding(DesignSpace.large)
    }

    private var description: String {
        if isNavigationActive {
            return "Your route continues in the mini map while the dashboard remains available."
        }
        return "Follow a GPX, navigate to a destination, or record a new route."
    }

    private enum Constants {
        static let iconSize: CGFloat = 58
        static let eyebrowTracking: CGFloat = 1.1
        static let descriptionWidth: CGFloat = 330
        static let buttonWidth: CGFloat = 260
    }
}
