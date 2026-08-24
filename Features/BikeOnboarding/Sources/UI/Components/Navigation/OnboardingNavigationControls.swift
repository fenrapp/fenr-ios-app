import DesignSystem
import SwiftUI

struct OnboardingNavigationControls: View {
    let step: BikeOnboardingStep
    let isContinueDisabled: Bool
    let isContinueBusy: Bool
    let onContinue: () -> Void

    init(
        step: BikeOnboardingStep,
        isContinueDisabled: Bool = false,
        isContinueBusy: Bool = false,
        onContinue: @escaping () -> Void
    ) {
        self.step = step
        self.isContinueDisabled = isContinueDisabled
        self.isContinueBusy = isContinueBusy
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: DesignSpace.small) {
            OnboardingProgressView(currentStep: step)

            if step != .connect {
                Button(action: onContinue) {
                    buttonContent
                        .frame(maxWidth: .infinity, minHeight: Constants.buttonHeight)
                }
                .disabled(isContinueDisabled || isContinueBusy)
                .onboardingPrimaryButtonStyle()
                .controlSize(.large)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var buttonContent: some View {
        if isContinueBusy {
            ProgressView()
                .controlSize(.regular)
        } else {
            Text(step == .identify ? "Connect Bike" : "Continue")
        }
    }
}

private enum Constants {
    static let buttonHeight: CGFloat = 30
}

private extension View {
    @ViewBuilder
    func onboardingPrimaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
