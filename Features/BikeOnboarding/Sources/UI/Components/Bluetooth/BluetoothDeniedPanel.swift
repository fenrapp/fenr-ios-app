import DesignSystem
import SwiftUI

struct BluetoothDeniedPanel: View {
    let errorMessage: String?
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: DesignSpace.medium) {
            OnboardingMaterialPanel {
                VStack(alignment: .leading, spacing: DesignSpace.small) {
                    OnboardingFeatureRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Permission denied",
                        detail: errorMessage ?? Constants.defaultErrorMessage,
                        tint: DesignColor.critical
                    )
                    Divider()
                    VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                        instruction("Open iOS Settings")
                        instruction("Go to Privacy & Security")
                        instruction("Tap Bluetooth")
                        instruction("Enable Bluetooth for FENR")
                    }
                }
            }

            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private func instruction(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle")
            .font(.footnote)
            .foregroundStyle(DesignColor.secondaryText)
    }
}

private enum Constants {
    static let defaultErrorMessage = "Bluetooth access must be enabled before FENR can discover your bike."
}
