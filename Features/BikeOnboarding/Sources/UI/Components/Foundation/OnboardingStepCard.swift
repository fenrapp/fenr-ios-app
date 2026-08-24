import DesignSystem
import SwiftUI

struct OnboardingStepCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    private let content: Content

    init(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: DesignSpace.large) {
            VStack(spacing: DesignSpace.small) {
                ZStack {
                    Circle()
                        .fill(DesignColor.accent.opacity(Constants.heroBackgroundOpacity))
                    Image(systemName: icon)
                        .font(.system(size: Constants.iconSize, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DesignColor.accent)
                }
                .frame(width: Constants.heroSize, height: Constants.heroSize)
                .accessibilityHidden(true)

                VStack(spacing: DesignSpace.extraSmall) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DesignColor.primaryText)
                    Text(subtitle)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DesignColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .frame(maxWidth: .infinity)
    }

}

private enum Constants {
    static let iconSize: CGFloat = 42
    static let heroSize: CGFloat = 104
    static let heroBackgroundOpacity = 0.16
}
