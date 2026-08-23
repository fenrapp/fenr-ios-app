import DesignSystem
import SwiftUI

struct OnboardingNavigationControls: View {
    let step: BikeOnboardingStep
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        HStack {
            if step != .welcome {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
            }
            Spacer()
            if step != .connect {
                Button(step == .identify ? "Connect" : "Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("Onboarding controls") {
    OnboardingNavigationControls(step: .identify, onBack: {}, onContinue: {})
        .padding()
}
