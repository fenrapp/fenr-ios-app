import DesignSystem
import SwiftUI

struct ConnectBikeOnboardingStepView: View {
    let viewState: BikeOnboardingViewState
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    var body: some View {
        OnboardingStepCard(
            icon: "antenna.radiowaves.left.and.right",
            title: "Connect your bike",
            subtitle: "Keep the bike on and nearby while FENR starts telemetry."
        ) {
            VStack(spacing: DesignSpace.medium) {
                ConnectionTimelineView(currentPhase: viewState.connectionPhase)
                connectionStatusPanel
                if viewState.errorMessage != nil {
                    bluetoothSettingsButton
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }

    private var connectionStatusPanel: some View {
        OnboardingMaterialPanel {
            HStack(spacing: DesignSpace.small) {
                if viewState.isConnecting {
                    ProgressView()
                } else {
                    Image(systemName: connectionStatusIcon)
                        .foregroundStyle(connectionStatusTint)
                }
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(connectionStatusTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(viewState.errorMessage ?? viewState.connectionDetail)
                        .font(.footnote)
                        .foregroundStyle(DesignColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var bluetoothSettingsButton: some View {
        if viewState.showsBluetoothSettingsButton {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
        }
    }

    private var connectionStatusIcon: String {
        viewState.errorMessage == nil ? "info.circle" : "exclamationmark.triangle.fill"
    }

    private var connectionStatusTint: Color {
        viewState.errorMessage == nil ? DesignColor.accent : DesignColor.critical
    }

    private var connectionStatusTitle: String {
        viewState.errorMessage == nil ? "Connection status" : "Connection failed"
    }
}
