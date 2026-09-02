import Foundation
import SwiftUI

struct DashboardCardVisibilityToggle: View {
    let title: LocalizedStringResource
    let isEnabled: Bool
    let disabledHint: LocalizedStringResource?
    @Binding var isVisible: Bool

    var body: some View {
        Toggle(.dashboardCardSettingsShowCard(String(localized: title)), isOn: $isVisible)
            .labelsHidden()
            .disabled(!isEnabled)
            .accessibilityLabel(.dashboardCardSettingsShowCard(String(localized: title)))
            .accessibilityHint(
                isEnabled
                    ? .dashboardCardSettingsVisibilityHint
                    : disabledHint ?? .dashboardCardSettingsCannotHideHint
            )
    }
}
