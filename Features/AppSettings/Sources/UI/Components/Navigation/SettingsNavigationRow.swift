import SwiftUI

struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let detail: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.spacing) {
                Image(systemName: icon)
                    .foregroundStyle(.tint)
                    .frame(width: Constants.iconWidth)

                VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let labelSpacing: CGFloat = 2
        static let iconWidth: CGFloat = 24
    }
}
