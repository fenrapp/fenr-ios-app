import DesignSystem
import SwiftUI

struct RideNavigationRouteOptionsView: View {
    let options: [RideNavigationRoadRouteOption]
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: DesignSpace.extraSmall) {
            ForEach(options) { option in
                Button { onSelect(option.id) } label: {
                    HStack(spacing: DesignSpace.extraSmall) {
                        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                            Text(option.detail)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if option.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignColor.accent)
                        }
                    }
                    .padding(.horizontal, DesignSpace.small)
                    .frame(minHeight: Constants.optionHeight)
                    .background(
                        option.isSelected ? DesignColor.controlSurface : Color.clear,
                        in: RoundedRectangle(cornerRadius: DesignRadius.medium)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSpace.extraSmall)
        .rideNavigationGlassSurface(cornerRadius: Constants.surfaceRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum Constants {
        static let optionHeight: CGFloat = 52
        static let surfaceRadius: CGFloat = 18
    }
}
