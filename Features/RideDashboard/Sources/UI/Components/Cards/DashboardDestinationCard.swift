import DesignSystem
import SwiftUI

struct DashboardDestinationCard: View {
    let symbolName: String
    let eyebrow: LocalizedStringResource
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let buttonTitle: LocalizedStringResource
    let buttonSymbolName: String
    let accessibilityIdentifier: String
    let open: () -> Void

    var body: some View {
        VStack(spacing: DesignSpace.large) {
            VStack(spacing: DesignSpace.medium) {
                Image(systemName: symbolName)
                    .font(.system(size: Constants.iconSize, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DesignColor.accent)
                VStack(spacing: DesignSpace.extraSmall) {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .tracking(Constants.eyebrowTracking)
                        .foregroundStyle(DesignColor.secondaryText)
                    Text(title)
                        .font(.title2.weight(.bold))
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(DesignColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Constants.descriptionWidth)
            }
            Button(action: open) {
                Label(buttonTitle, systemImage: buttonSymbolName)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .dashboardPagingButton()
            .frame(maxWidth: Constants.buttonWidth)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(DesignSpace.large)
    }

    private enum Constants {
        static let iconSize: CGFloat = 58
        static let eyebrowTracking: CGFloat = 1.1
        static let descriptionWidth: CGFloat = 330
        static let buttonWidth: CGFloat = 260
    }
}
