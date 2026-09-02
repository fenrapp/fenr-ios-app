import SwiftUI

struct OnboardingSuccessView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var messageIsFocused: Bool
    @State private var haloIsVisible = false
    @State private var checkmarkIsVisible = false

    let requiresExplicitContinue: Bool
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Constants.contentSpacing) {
                    Spacer(minLength: Constants.minimumSpacer)
                    successSymbol
                    successMessage
                    Spacer(minLength: Constants.minimumSpacer)
                    if requiresExplicitContinue {
                        OnboardingPrimaryButton(
                            title: "Continue to Dashboard",
                            systemImage: "arrow.right",
                            action: onContinue
                        )
                    }
                }
                .frame(maxWidth: Constants.maximumContentWidth)
                .frame(
                    maxWidth: .infinity,
                    minHeight: max(.zero, proxy.size.height - Constants.verticalPadding * 2)
                )
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, Constants.verticalPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task {
            if requiresExplicitContinue {
                await Task.yield()
                messageIsFocused = true
            }
            guard !reduceMotion else { return }
            withAnimation(
                .spring(
                    response: Constants.haloSpringResponse,
                    dampingFraction: Constants.haloSpringDamping
                )
            ) {
                haloIsVisible = true
            }
            try? await Task.sleep(for: Constants.checkmarkDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: Constants.checkmarkDuration)) {
                checkmarkIsVisible = true
            }
        }
    }

    private var successSymbol: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(Constants.circleOpacity))
                .frame(width: symbolSize, height: symbolSize)
                .scaleEffect(reduceMotion || haloIsVisible ? 1 : Constants.initialHaloScale)
            Image(systemName: "checkmark")
                .font(.system(size: iconSize, weight: .bold))
                .scaleEffect(reduceMotion || checkmarkIsVisible ? 1 : Constants.initialCheckmarkScale)
                .opacity(reduceMotion || checkmarkIsVisible ? 1 : .zero)
        }
        .accessibilityHidden(true)
    }

    private var successMessage: some View {
        VStack(spacing: Constants.messageSpacing) {
            Text("Your bike is ready.")
                .font(.largeTitle.bold())
            Text("Live telemetry is flowing into FENR.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your bike is ready. Live telemetry is flowing into FENR.")
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($messageIsFocused)
    }

    private var symbolSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Constants.accessibilityCircleSize : Constants.circleSize
    }

    private var iconSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Constants.accessibilityIconSize : Constants.iconSize
    }
}

private extension OnboardingSuccessView {
    enum Constants {
        static let contentSpacing: CGFloat = 20
        static let messageSpacing: CGFloat = 12
        static let circleOpacity = 0.12
        static let circleSize: CGFloat = 120
        static let accessibilityCircleSize: CGFloat = 92
        static let initialHaloScale: CGFloat = 0.84
        static let iconSize: CGFloat = 48
        static let accessibilityIconSize: CGFloat = 38
        static let initialCheckmarkScale: CGFloat = 0.9
        static let minimumSpacer: CGFloat = 20
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 20
        static let maximumContentWidth: CGFloat = 560
        static let haloSpringResponse = 0.3
        static let haloSpringDamping = 0.82
        static let checkmarkDelay: Duration = .milliseconds(80)
        static let checkmarkDuration = 0.2
    }
}
