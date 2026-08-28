import DesignSystem
import SwiftUI

struct WelcomeOnboardingStepView: View {
    var body: some View {
        OnboardingStepCard(
            icon: "gauge.with.dots.needle.67percent",
            title: "Your Stark dashboard",
            subtitle: "Connect once and turn your iPhone into a focused ride and battery display."
        ) {
            VStack(spacing: DesignSpace.small) {
                OnboardingMaterialPanel {
                    OnboardingFeatureRow(
                        icon: "wave.3.right",
                        title: "Live telemetry",
                        detail: "See speed, battery state, charging detail, and diagnostics from your bike."
                    )
                }
                OnboardingMaterialPanel {
                    OnboardingFeatureRow(
                        icon: "shield.lefthalf.filled",
                        title: "Guarded configuration",
                        detail: "FENR changes only verified settings; ride safety controls remain read-only.",
                        tint: DesignColor.positive
                    )
                }
            }
        }
    }
}
