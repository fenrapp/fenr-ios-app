import SwiftUI

struct OnboardingPairingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let viewState: BikeOnboardingViewState
    let onCopyAndPair: () -> Void

    var body: some View {
        OnboardingStepLayout(
            eyebrow: BikeOnboardingL10n.text(.bikeOnboardingPairingEyebrow),
            title: BikeOnboardingL10n.text(.bikeOnboardingPairingTitle),
            detail: BikeOnboardingL10n.text(.bikeOnboardingPairingDetail)
        ) {
            VStack(spacing: Constants.spacing) {
                bikeIdentity
                OnboardingPairingCodeView(pin: viewState.pairingPIN)
                Text(.bikeOnboardingPairingPrivacyDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } footer: {
            OnboardingPrimaryButton(
                title: BikeOnboardingL10n.text(.bikeOnboardingActionCopyAndPair),
                systemImage: "doc.on.doc",
                accessibilityLabel: BikeOnboardingL10n.text(.bikeOnboardingAccessibilityCopyAndPair),
                action: onCopyAndPair
            )
        }
    }

    @ViewBuilder private var bikeIdentity: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Constants.identitySpacing) {
                identityTitle
                vinText
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(identityAccessibilityLabel)
        } else {
            HStack(spacing: Constants.identitySpacing) {
                identityTitle
                Spacer(minLength: .zero)
                vinText
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(identityAccessibilityLabel)
        }
    }

    private var identityTitle: some View {
        Label(viewState.selectedBikeTitle, systemImage: "bolt.fill")
            .font(.headline)
    }

    private var vinText: some View {
        Text(viewState.formattedVIN)
            .font(.caption.monospaced().weight(.medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var identityAccessibilityLabel: String {
        BikeOnboardingL10n.text(.bikeOnboardingAccessibilityBikeIdentity(
            viewState.selectedBikeTitle,
            viewState.accessibilityVIN
        ))
    }
}

private extension OnboardingPairingView {
    enum Constants {
        static let spacing: CGFloat = 20
        static let identitySpacing: CGFloat = 12
    }
}
