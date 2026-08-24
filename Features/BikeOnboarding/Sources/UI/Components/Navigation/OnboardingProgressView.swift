import DesignSystem
import SwiftUI

struct OnboardingProgressView: View {
    let currentStep: BikeOnboardingStep

    var body: some View {
        HStack(spacing: DesignSpace.small) {
            ForEach(BikeOnboardingStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? DesignColor.accent : DesignColor.inactive)
                    .frame(width: Constants.dotSize, height: Constants.dotSize)
                    .overlay {
                        if step == currentStep {
                            Circle()
                                .stroke(
                                    DesignColor.accent.opacity(Constants.currentRingOpacity),
                                    lineWidth: Constants.currentRingWidth
                                )
                                .frame(width: Constants.currentDotSize, height: Constants.currentDotSize)
                        }
                    }
            }
        }
        .padding(.vertical, DesignSpace.small)
        .padding(.horizontal, DesignSpace.medium)
        .accessibilityLabel("Setup step \(currentStep.rawValue + 1) of \(BikeOnboardingStep.allCases.count)")
    }
}

private enum Constants {
    static let dotSize: CGFloat = 7
    static let currentDotSize: CGFloat = 18
    static let currentRingOpacity = 0.35
    static let currentRingWidth: CGFloat = 2
}
