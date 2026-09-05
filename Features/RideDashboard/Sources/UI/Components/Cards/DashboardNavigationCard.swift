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
                    Text(.rideDashboardNavigationTitle)
                        .font(.caption.weight(.semibold))
                        .tracking(Constants.eyebrowTracking)
                        .foregroundStyle(DesignColor.secondaryText)
                    Text(
                        isNavigationActive
                            ? rideDashboardLocalized(.rideDashboardNavigationRunning)
                            : rideDashboardLocalized(.rideDashboardNavigationTagline)
                    )
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
                    Text(
                        isNavigationActive
                            ? rideDashboardLocalized(.rideDashboardNavigationReturn)
                            : rideDashboardLocalized(.rideDashboardNavigationOpen)
                    )
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .dashboardPagingButton()
            .frame(maxWidth: Constants.buttonWidth)
            .accessibilityIdentifier("dashboard.navigation.open")
        }
        .padding(DesignSpace.large)
    }

    private var description: String {
        if isNavigationActive {
            return rideDashboardLocalized(.rideDashboardNavigationRunningDetail)
        }
        return rideDashboardLocalized(.rideDashboardNavigationInactiveDetail)
    }

    private enum Constants {
        static let iconSize: CGFloat = 58
        static let eyebrowTracking: CGFloat = 1.1
        static let descriptionWidth: CGFloat = 330
        static let buttonWidth: CGFloat = 260
    }
}
