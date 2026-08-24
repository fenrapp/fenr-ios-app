import DesignSystem
import SwiftUI

struct OnboardingNavigationControls: View {
    let step: BikeOnboardingStep
    let isContinueDisabled: Bool
    let isContinueBusy: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    init(
        step: BikeOnboardingStep,
        isContinueDisabled: Bool = false,
        isContinueBusy: Bool = false,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.step = step
        self.isContinueDisabled = isContinueDisabled
        self.isContinueBusy = isContinueBusy
        self.onBack = onBack
        self.onContinue = onContinue
    }

    var body: some View {
        HStack {
            if step != .welcome {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
            }
            Spacer()
            if step != .connect {
                Button(action: onContinue) {
                    if isContinueBusy {
                        ProgressView()
                    } else {
                        Text(step == .identify ? "Connect" : "Continue")
                    }
                }
                .disabled(isContinueDisabled || isContinueBusy)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("Onboarding controls") {
    OnboardingNavigationControls(step: .identify, onBack: {}, onContinue: {})
        .padding()
}
