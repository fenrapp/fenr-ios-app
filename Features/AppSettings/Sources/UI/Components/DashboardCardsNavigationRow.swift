import SwiftUI

struct DashboardCardsNavigationRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.spacing) {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(.tint)
                    .frame(width: Constants.iconWidth)

                VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                    Text("Dashboard cards")
                        .foregroundStyle(.primary)
                    Text("Choose their order and visibility")
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
        .accessibilityIdentifier("settings.dashboardCards")
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let labelSpacing: CGFloat = 2
        static let iconWidth: CGFloat = 24
    }
}

#Preview("Dashboard cards navigation") {
    List {
        Section("Ride dashboard") {
            DashboardCardsNavigationRow(action: {})
        }
    }
}
