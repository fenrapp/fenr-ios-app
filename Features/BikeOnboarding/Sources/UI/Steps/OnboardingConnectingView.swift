import SwiftUI

struct OnboardingConnectingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let viewState: BikeOnboardingViewState
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        OnboardingStepLayout(
            eyebrow: BikeOnboardingL10n.text(.bikeOnboardingConnectionEyebrow),
            title: viewState.connectionState.title,
            detail: viewState.connectionState.detail
        ) {
            Group {
                if let phase = viewState.connectionState.phase {
                    VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                        OnboardingConnectionProgressView(phase: phase)
                        if viewState.didCopyPIN {
                            copiedCodeConfirmation
                        }
                    }
                } else {
                    OnboardingConnectionRecoveryView(
                        bikeTitle: viewState.selectedBikeTitle,
                        formattedVIN: viewState.formattedVIN,
                        accessibilityVIN: viewState.accessibilityVIN
                    )
                }
            }
            .transition(.opacity)
        } footer: {
            VStack(spacing: Constants.footerSpacing) {
                if let actionTitle = viewState.connectionState.primaryActionTitle {
                    OnboardingPrimaryButton(
                        title: actionTitle,
                        systemImage: "arrow.clockwise",
                        action: onRetry
                    )
                }
                Button(BikeOnboardingL10n.text(.bikeOnboardingActionChooseAnotherBike), action: onCancel)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Constants.minimumActionHeight)
                    .contentShape(Rectangle())
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: Constants.recoveryTransitionDuration),
            value: viewState.connectionState
        )
    }

    private var copiedCodeConfirmation: some View {
        HStack(spacing: Constants.confirmationSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(.bikeOnboardingPairingCodeCopied)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private extension OnboardingConnectingView {
    enum Constants {
        static let contentSpacing: CGFloat = 22
        static let confirmationSpacing: CGFloat = 8
        static let footerSpacing: CGFloat = 8
        static let minimumActionHeight: CGFloat = 44
        static let recoveryTransitionDuration = 0.18
    }
}
