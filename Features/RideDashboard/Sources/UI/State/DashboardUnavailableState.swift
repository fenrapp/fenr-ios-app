import DesignSystem
import SwiftUI

@MainActor
enum DashboardUnavailableState {
    static var rotationRequired: some View {
        VStack(spacing: DesignSpace.small) {
            Image(systemName: "rotate.right")
                .font(.system(size: Constants.iconSize, weight: .medium))
                .foregroundStyle(DesignColor.informational)
            Text("Rotate to landscape")
                .font(.title3.weight(.semibold))
            Text("The ride dashboard is designed for landscape viewing.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSpace.large)
    }

    static func disconnected(
        detail: String,
        onDiagnostics: @escaping () -> Void
    ) -> some View {
        VStack(spacing: DesignSpace.small) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(.secondary)
            Text("No live telemetry").font(.title3.weight(.semibold))
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Diagnostics", action: onDiagnostics).buttonStyle(.borderedProminent)
        }
        .padding(DesignSpace.large)
    }

    static func connecting(detail: String) -> some View {
        VStack(spacing: DesignSpace.small) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to bike").font(.title3.weight(.semibold))
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSpace.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to bike. \(detail)")
    }

    private enum Constants {
        static let iconSize: CGFloat = 42
    }
}
