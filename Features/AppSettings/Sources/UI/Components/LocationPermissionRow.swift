#if os(iOS)
import DesignSystem
import SwiftUI
import UIKit

struct LocationPermissionRow: View {
    let status: LocationPermissionViewState
    let onRequestAccess: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch status {
        case .authorized:
            Label("Location access enabled", systemImage: "location.fill")
                .foregroundStyle(DesignColor.positive)
        case .notDetermined:
            Button("Allow location access", action: onRequestAccess)
        case .denied:
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                Text("Location access is required for GPS speed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open iOS Settings", action: openSystemSettings)
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview("Location permission") {
    Form {
        LocationPermissionRow(status: .notDetermined, onRequestAccess: {})
    }
}
#endif
