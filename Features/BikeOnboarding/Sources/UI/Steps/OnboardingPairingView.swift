import SwiftUI

struct OnboardingPairingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let viewState: BikeOnboardingViewState
    let onCopyAndPair: () -> Void

    var body: some View {
        OnboardingStepLayout(
            eyebrow: "PAIRING",
            title: "Pair your bike.",
            detail: "When iOS asks for a six-digit code, paste this one. FENR copies it before pairing starts."
        ) {
            VStack(spacing: Constants.spacing) {
                bikeIdentity
                OnboardingPairingCodeView(pin: viewState.pairingPIN)
                Text("Generated on this iPhone and copied only when you tap Copy & Pair.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } footer: {
            OnboardingPrimaryButton(
                title: "Copy & Pair",
                systemImage: "doc.on.doc",
                accessibilityLabel: "Copy pairing code and start pairing",
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
        "\(viewState.selectedBikeTitle). VIN \(viewState.accessibilityVIN)."
    }
}

private extension OnboardingPairingView {
    enum Constants {
        static let spacing: CGFloat = 20
        static let identitySpacing: CGFloat = 12
    }
}
