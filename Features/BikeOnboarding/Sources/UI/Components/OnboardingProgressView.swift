import DesignSystem
import SwiftUI

struct OnboardingProgressView: View {
    let currentStep: BikeOnboardingStep

    var body: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            ForEach(BikeOnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? DesignColor.accent : DesignColor.inactive)
                    .frame(height: DesignSpace.extraExtraSmall)
            }
        }
        .accessibilityLabel("Setup step \(currentStep.rawValue + 1) of \(BikeOnboardingStep.allCases.count)")
    }
}

#Preview("Onboarding progress") {
    OnboardingProgressView(currentStep: .identify)
        .padding()
}
