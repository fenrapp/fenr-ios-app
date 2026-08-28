import SwiftUI

struct DashboardCardVisibilityToggle: View {
    let title: String
    let isEnabled: Bool
    @Binding var isVisible: Bool

    var body: some View {
        Toggle("Show \(title)", isOn: $isVisible)
            .labelsHidden()
            .disabled(!isEnabled)
            .accessibilityLabel("Show \(title)")
            .accessibilityHint(
                isEnabled
                    ? "Controls whether this card appears on the dashboard"
                    : "At least one card must remain visible"
            )
    }
}
