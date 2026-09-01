import SwiftUI

struct RideHistorySummaryHeader: View {
    let summary: RideHistoryViewState.Summary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            identityHeader

            Divider()

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Constants.iconSpacing) {
                    summaryValue(summary.distanceText, label: "Distance")
                    Divider()
                    summaryValue(summary.durationText, label: "Ride time")
                }
            } else {
                HStack(spacing: .zero) {
                    summaryValue(summary.distanceText, label: "Distance")
                    Divider()
                        .padding(.horizontal, Constants.dividerPadding)
                    summaryValue(summary.durationText, label: "Ride time")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var identityHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Constants.iconSpacing) {
                identityIcon
                identityText
            }
        } else {
            HStack(spacing: Constants.iconSpacing) {
                identityIcon
                identityText
            }
        }
    }

    private var identityIcon: some View {
        Image(systemName: "motorcycle.fill")
            .font(.title2)
            .foregroundStyle(.tint)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(.tint.opacity(Constants.iconBackgroundOpacity), in: Circle())
    }

    private var identityText: some View {
        VStack(alignment: .leading, spacing: Constants.textSpacing) {
            Text(summary.rideCountText)
                .font(.title2.weight(.bold))
            Text("Saved ride history")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
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
        .fixedSize(horizontal: false, vertical: true)
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
