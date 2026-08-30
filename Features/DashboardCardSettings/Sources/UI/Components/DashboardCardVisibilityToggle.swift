import SwiftUI

struct DashboardCardVisibilityToggle: View {
    let title: String
    let isEnabled: Bool
    let disabledHint: String?
    @Binding var isVisible: Bool

    var body: some View {
        Toggle("Show \(title)", isOn: $isVisible)
            .labelsHidden()
            .disabled(!isEnabled)
            .accessibilityLabel("Show \(title)")
            .accessibilityHint(
                isEnabled
                    ? "Controls whether this card appears on the dashboard"
                    : disabledHint ?? "This card cannot be hidden"
            )
    }
}
