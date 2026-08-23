import DesignSystem
import SwiftUI

struct OnboardingStepCard<Content: View>: View {
    let icon: String
    let title: String
    private let content: Content

    init(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.medium) {
            Image(systemName: icon)
                .font(.system(size: OnboardingStepCardConstants.iconSize))
                .foregroundStyle(DesignColor.accent)
            Text(title)
                .font(.title.bold())
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSpace.large)
        .background(DesignColor.surface, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
    }

}

private enum OnboardingStepCardConstants {
    static let iconSize: CGFloat = 38
}

#Preview("Onboarding step") {
    OnboardingStepCard(icon: "bluetooth", title: "Prepare your bike") {
        Text("Turn on the bike and keep it nearby.")
    }
    .padding()
}
