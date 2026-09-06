import SwiftUI

#Preview("Connecting - finding") {
    OnboardingConnectingView(
        viewState: .init(step: .connecting, connectionState: .inProgress(.finding)),
        onRetry: {}, onCancel: {}
    )
}

#Preview("Connecting - securing - code copied") {
    OnboardingConnectingView(
        viewState: .init(step: .connecting, connectionState: .inProgress(.securing), didCopyPIN: true),
        onRetry: {}, onCancel: {}
    )
}

#Preview("Connecting - live - large text") {
    OnboardingConnectingView(
        viewState: .init(step: .connecting, connectionState: .inProgress(.live)),
        onRetry: {}, onCancel: {}
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Onboarding success") {
    OnboardingSuccessView(requiresExplicitContinue: false, onContinue: {})
}

#Preview("Onboarding success - explicit continue - large text") {
    OnboardingSuccessView(requiresExplicitContinue: true, onContinue: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
