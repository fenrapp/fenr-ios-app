import DesignSystem
import SwiftUI

struct DashboardChargingControlStatusBadge: View {
    let status: ChargingDashboardStatusViewData

    var body: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            if status.isError {
                Image(systemName: "exclamationmark")
                    .font(.caption2.weight(.bold))
            } else {
                ProgressView()
                    .controlSize(.mini)
                    .tint(tint)
            }
            Text(status.text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
        .background(tint.opacity(Constants.backgroundOpacity), in: Capsule())
        .transition(.opacity.combined(with: .scale(scale: Constants.transitionScale)))
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        status.isError ? DesignColor.critical : DesignColor.informational
    }

    private enum Constants {
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 5
        static let backgroundOpacity = 0.12
        static let transitionScale = 0.96
    }
}
