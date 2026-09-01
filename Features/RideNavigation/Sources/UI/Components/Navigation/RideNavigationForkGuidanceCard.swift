import DesignSystem
import SwiftUI

struct RideNavigationForkGuidanceCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let guidance: RideNavigationForkGuidance
    let isMonochrome: Bool

    var body: some View {
        HStack(spacing: DesignSpace.medium) {
            Image(systemName: guidance.systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(iconColor)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(guidance.instructionText)
                    .font(.headline.weight(.bold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if let distanceText = guidance.distanceText {
                    Text(distanceText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: .zero)
        }
        .padding(.horizontal, DesignSpace.medium)
        .frame(maxWidth: Constants.maximumWidth, minHeight: Constants.minimumHeight)
        .rideNavigationGlassSurface(cornerRadius: Constants.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("rideNavigation.forkGuidance")
    }

    private var iconColor: Color {
        guard !isMonochrome else { return .white }
        return guidance.emphasis == .warning ? DesignColor.warning : DesignColor.accent
    }

    private enum Constants {
        static let maximumWidth: CGFloat = 380
        static let minimumHeight: CGFloat = 64
        static let cornerRadius: CGFloat = 20
        static let iconSize: CGFloat = 40
    }
}
