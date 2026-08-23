import DesignSystem
import SwiftUI

struct DashboardIndicatorRail: View {
    let isHighBeamOn: Bool
    let isLeftBlinkerOn: Bool
    let isBrakeActive: Bool
    let isRightBlinkerOn: Bool
    let isFaultActive: Bool

    var body: some View {
        HStack(spacing: .zero) {
            indicator("headlight.high.beam", active: isHighBeamOn, label: "High beam", tint: DesignColor.informational)
            divider
            indicator("arrow.left", active: isLeftBlinkerOn, label: "Left turn", tint: DesignColor.positive)
            divider
            indicator("hand.raised.fill", active: isBrakeActive, label: "Brake", tint: DesignColor.warning)
            divider
            indicator("arrow.right", active: isRightBlinkerOn, label: "Right turn", tint: DesignColor.positive)
            divider
            indicator(
                "exclamationmark.triangle.fill",
                active: isFaultActive,
                label: "Fault",
                tint: DesignColor.critical
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSpace.extraSmall)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignColor.border)
                .frame(height: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignColor.border)
            .frame(width: 1, height: Constants.dividerHeight)
            .padding(.horizontal, Constants.dividerHorizontalPadding)
    }

    private func indicator(_ symbol: String, active: Bool, label: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: Constants.iconSize, weight: .semibold))
            .foregroundStyle(active ? tint : DesignColor.inactive)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(label)
            .accessibilityValue(active ? "On" : "Off")
    }

    private enum Constants {
        static let dividerHeight: CGFloat = 22
        static let dividerHorizontalPadding: CGFloat = 14
        static let iconSize: CGFloat = 26.4
    }
}
