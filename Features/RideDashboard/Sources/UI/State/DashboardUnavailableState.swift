import DesignSystem
import SwiftUI

@MainActor
enum DashboardUnavailableState {
    static var rotationRequired: some View {
        VStack(spacing: DesignSpace.small) {
            Image(systemName: "rotate.right")
                .font(.system(size: Constants.iconSize, weight: .medium))
                .foregroundStyle(DesignColor.informational)
            Text(.rideDashboardUnavailableRotateTitle)
                .font(.title3.weight(.semibold))
            Text(.rideDashboardUnavailableRotateDetail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSpace.large)
    }

    static func disconnected(
        detail: String,
        onRetryConnection: @escaping () -> Void
    ) -> some View {
        VStack(spacing: DesignSpace.small) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(.secondary)
            Text(.rideDashboardUnavailableTelemetryTitle).font(.title3.weight(.semibold))
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(
                .rideDashboardUnavailableRetryConnectionAction,
                action: onRetryConnection
            )
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignSpace.large)
    }

    static func connecting(detail: String) -> some View {
        VStack(spacing: DesignSpace.small) {
            ProgressView()
                .controlSize(.large)
            Text(.rideDashboardUnavailableConnectingTitle).font(.title3.weight(.semibold))
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSpace.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rideDashboardLocalized(.rideDashboardUnavailableConnectingAccessibility(detail)))
    }

    private enum Constants {
        static let iconSize: CGFloat = 42
    }
}
