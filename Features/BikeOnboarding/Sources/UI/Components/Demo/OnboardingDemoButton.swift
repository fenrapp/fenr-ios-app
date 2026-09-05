import DesignSystem
import SwiftUI

struct OnboardingDemoButton: View {
    let action: () -> Void

    var body: some View {
        Button(.bikeOnboardingExploreDemo, action: action)
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, DesignSpace.small)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("onboarding.exploreDemo")
    }
}
