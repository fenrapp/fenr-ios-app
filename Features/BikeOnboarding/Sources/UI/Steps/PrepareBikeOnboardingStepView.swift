import DesignSystem
import SwiftUI

struct PrepareBikeOnboardingStepView: View {
    let viewState: BikeOnboardingViewState
    let onOpenSettings: () -> Void

    var body: some View {
        OnboardingStepCard(
            icon: icon,
            title: title,
            subtitle: subtitle
        ) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewState.isRequestingBluetoothAccess {
            OnboardingMaterialPanel {
                HStack(spacing: DesignSpace.small) {
                    ProgressView()
                    Text("Waiting for the iOS Bluetooth prompt...")
                        .font(.subheadline.weight(.semibold))
                }
            }
        } else if viewState.showsBluetoothSettingsButton {
            BluetoothDeniedPanel(
                errorMessage: viewState.errorMessage,
                onOpenSettings: onOpenSettings
            )
        } else {
            checklist
        }
    }

    private var checklist: some View {
        VStack(spacing: DesignSpace.small) {
            OnboardingMaterialPanel {
                OnboardingFeatureRow(
                    icon: "power",
                    title: "Wake the bike",
                    detail: "Turn it on and keep it near your iPhone."
                )
            }
            OnboardingMaterialPanel {
                OnboardingFeatureRow(
                    icon: "link",
                    title: "Free the connection",
                    detail: "Turn off Arkenstone so FENR can connect directly."
                )
            }
            OnboardingMaterialPanel {
                OnboardingFeatureRow(
                    icon: "bonjour",
                    title: "Allow Bluetooth",
                    detail: "iOS will ask for permission on the next step."
                )
            }
        }
    }

    private var icon: String {
        if viewState.showsBluetoothSettingsButton {
            return "exclamationmark.circle"
        }
        return "antenna.radiowaves.left.and.right"
    }

    private var title: String {
        viewState.showsBluetoothSettingsButton ? "Bluetooth access needed" : "Prepare your bike"
    }

    private var subtitle: String {
        if viewState.showsBluetoothSettingsButton {
            return "Enable Bluetooth access in Settings, then return to FENR."
        }
        if viewState.isRequestingBluetoothAccess {
            return "Please respond to the system permission request."
        }
        return "A few quick checks before FENR connects."
    }
}
