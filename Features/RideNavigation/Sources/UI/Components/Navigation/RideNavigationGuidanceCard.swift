import DesignSystem
import SwiftUI

struct RideNavigationGuidanceCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let state: RideNavigationViewState
    let isMonochrome: Bool
    let usesFullWidth: Bool

    @ViewBuilder
    var body: some View {
        if state.isRerouting {
            HStack(spacing: DesignSpace.small) {
                ProgressView().controlSize(.small)
                Text("REROUTING").font(.headline.weight(.semibold))
            }
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            .padding(.horizontal, DesignSpace.medium)
            .frame(minHeight: Constants.height)
            .rideNavigationGlassSurface(cornerRadius: Constants.radius)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let guidance = state.guidance {
            HStack(spacing: DesignSpace.small) {
                Image(systemName: guidance.systemImage)
                    .font(.headline)
                    .rotationEffect(.degrees(guidance.rotationDegrees))
                    .animation(.smooth, value: guidance.rotationDegrees)
                    .foregroundStyle(
                        isMonochrome ? Color.white
                            : guidance.emphasis == .warning ? DesignColor.warning : DesignColor.accent
                    )
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(guidance.text)
                        .font(.headline.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    if let detail = guidance.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                }
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                Spacer(minLength: .zero)
            }
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            .padding(.horizontal, DesignSpace.medium)
            .frame(maxWidth: usesFullWidth ? .infinity : Constants.width)
            .frame(minHeight: Constants.height)
            .rideNavigationGlassSurface(cornerRadius: Constants.radius)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private enum Constants {
        static let width: CGFloat = 360
        static let height: CGFloat = 52
        static let radius: CGFloat = 18
    }
}
