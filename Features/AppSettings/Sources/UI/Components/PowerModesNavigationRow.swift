import SwiftUI

struct PowerModesNavigationRow: View {
    let state: PowerModeNavigationViewState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.spacing) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.tint)
                    .frame(width: Constants.iconWidth)

                VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                    Text("Power modes")
                        .foregroundStyle(.primary)
                    Text(state.detail)
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
        .accessibilityIdentifier("settings.powerModes")
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let labelSpacing: CGFloat = 2
        static let iconWidth: CGFloat = 24
    }
}
