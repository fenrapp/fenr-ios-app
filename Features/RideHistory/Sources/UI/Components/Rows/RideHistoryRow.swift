import SwiftUI

struct RideHistoryRow: View {
    let ride: RideHistoryViewState.Row
    let isDeleting: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                compactLayout
            }
        }
        .padding(.vertical, Constants.verticalPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ride.accessibilityLabel)
        .accessibilityValue(isDeleting ? String(localized: .rideHistoryDeleting) : "")
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: Constants.lineSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: Constants.minimumSpacing) {
                Text(ride.distanceText)
                    .font(.headline)
                Spacer(minLength: Constants.minimumSpacing)
                Text(ride.durationText)
                    .font(.subheadline.weight(.medium))
            }

            HStack(alignment: .firstTextBaseline, spacing: Constants.minimumSpacing) {
                Text(ride.timeText)
                Spacer(minLength: Constants.minimumSpacing)
                Text(ride.efficiencyText)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            deletionProgress
        }
        .monospacedDigit()
    }

    private var accessibilityLayout: some View {
        HStack(alignment: .top, spacing: Constants.minimumSpacing) {
            VStack(alignment: .leading, spacing: Constants.accessibilitySpacing) {
                Text(ride.distanceText)
                    .font(.headline)
                Text(ride.timeText)
                    .foregroundStyle(.secondary)
                Text(ride.durationText)
                Text(ride.efficiencyText)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            deletionProgress
        }
    }

    @ViewBuilder
    private var deletionProgress: some View {
        if isDeleting {
            ProgressView()
                .controlSize(.small)
        }
    }

    private enum Constants {
        static let minimumSpacing: CGFloat = 8
        static let lineSpacing: CGFloat = 3
        static let verticalPadding: CGFloat = 6
        static let accessibilitySpacing: CGFloat = 8
    }
}
