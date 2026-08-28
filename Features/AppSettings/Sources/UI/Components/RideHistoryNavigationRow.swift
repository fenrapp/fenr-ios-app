import SwiftUI

struct RideHistoryNavigationRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.spacing) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.tint)
                    .frame(width: Constants.iconWidth)

                VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                    Text("Ride history")
                        .foregroundStyle(.primary)
                    Text("Review saved rides and recent comparisons")
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
        .accessibilityIdentifier("settings.rideHistory")
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let labelSpacing: CGFloat = 2
        static let iconWidth: CGFloat = 24
    }
}

#Preview("Ride history navigation") {
    List {
        Section("Rides") {
            RideHistoryNavigationRow(action: {})
        }
    }
}
