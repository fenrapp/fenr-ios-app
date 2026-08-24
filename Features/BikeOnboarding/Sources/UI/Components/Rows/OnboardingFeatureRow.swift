import DesignSystem
import SwiftUI

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let detail: String
    var tint: Color = DesignColor.accent

    var body: some View {
        HStack(alignment: .center, spacing: DesignSpace.small) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .background(tint.opacity(Constants.iconBackgroundOpacity), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignColor.primaryText)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(DesignColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private enum Constants {
    static let iconSize: CGFloat = 36
    static let iconBackgroundOpacity = 0.14
}
