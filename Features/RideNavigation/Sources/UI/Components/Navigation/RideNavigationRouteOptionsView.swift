import DesignSystem
import SwiftUI

struct RideNavigationRouteOptionsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let options: [RideNavigationRoadRouteOption]
    let onSelect: (Int) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignSpace.extraSmall) { optionButtons }
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: DesignSpace.extraSmall) { optionButtons }
            }
        }
        .padding(DesignSpace.extraSmall)
        .rideNavigationGlassSurface(cornerRadius: Constants.surfaceRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var optionButtons: some View {
            ForEach(options) { option in
                Button { onSelect(option.id) } label: {
                    HStack(spacing: DesignSpace.extraSmall) {
                        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(
                                    horizontal: false,
                                    vertical: dynamicTypeSize.isAccessibilitySize
                                )
                            Text(option.detail)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if option.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignColor.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(
                        horizontal: false,
                        vertical: dynamicTypeSize.isAccessibilitySize
                    )
                    .padding(.horizontal, DesignSpace.small)
                    .frame(minHeight: Constants.optionHeight)
                    .background(
                        option.isSelected ? DesignColor.controlSurface : Color.clear,
                        in: RoundedRectangle(cornerRadius: DesignRadius.medium)
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(
                    horizontal: false,
                    vertical: dynamicTypeSize.isAccessibilitySize
                )
            }
    }

    private enum Constants {
        static let optionHeight: CGFloat = 52
        static let surfaceRadius: CGFloat = 18
    }
}
