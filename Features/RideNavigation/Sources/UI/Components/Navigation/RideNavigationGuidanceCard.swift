import DesignSystem
import SwiftUI

struct RideNavigationGuidanceCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    let state: RideNavigationViewState
    let isMonochrome: Bool

    @ViewBuilder
    var body: some View {
        if state.isRerouting {
            HStack(spacing: DesignSpace.small) {
                ProgressView().controlSize(.small)
                Text(.rideNavigationRerouting).font(.headline.weight(.semibold))
            }
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            .padding(.horizontal, DesignSpace.medium)
            .frame(minHeight: Constants.height)
            .rideNavigationGlassSurface(cornerRadius: Constants.radius)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("rideNavigation.guidance")
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let guidance = state.guidance {
            HStack(spacing: DesignSpace.small) {
                Image(systemName: guidance.systemImage)
                    .font(.headline)
                    .rotationEffect(.degrees(guidance.rotationDegrees))
                    .animation(.smooth, value: guidance.rotationDegrees)
                    .foregroundStyle(
                        isMonochrome ? focusPalette.foreground
                            : guidance.emphasis == .warning ? DesignColor.warning : DesignColor.accent
                    )
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(guidance.text)
                        .font(.headline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = guidance.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                Spacer(minLength: .zero)
            }
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            .padding(.horizontal, DesignSpace.medium)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Constants.height)
            .rideNavigationGlassSurface(cornerRadius: Constants.radius)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("rideNavigation.guidance")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var focusPalette: RideNavigationFocusPalette {
        RideNavigationFocusPalette(colorScheme: colorScheme)
    }

    private enum Constants {
        static let height: CGFloat = 52
        static let radius: CGFloat = 18
    }
}
