import SwiftUI

struct RideHistorySummaryHeader: View {
    let summary: RideHistoryViewState.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            HStack(spacing: Constants.iconSpacing) {
                Image(systemName: "motorcycle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .background(.tint.opacity(Constants.iconBackgroundOpacity), in: Circle())

                VStack(alignment: .leading, spacing: Constants.textSpacing) {
                    Text(summary.rideCountText)
                        .font(.title2.weight(.bold))
                    Text("Saved ride history")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: .zero) {
                summaryValue(summary.distanceText, label: "Distance")
                Divider()
                    .padding(.horizontal, Constants.dividerPadding)
                summaryValue(summary.durationText, label: "Ride time")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func summaryValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Constants.textSpacing) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Constants {
        static let iconSize: CGFloat = 44
        static let iconBackgroundOpacity = 0.12
        static let iconSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 16
        static let textSpacing: CGFloat = 2
        static let dividerPadding: CGFloat = 16
    }
}
