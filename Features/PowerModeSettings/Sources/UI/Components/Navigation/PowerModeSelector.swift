import DesignSystem
import SwiftUI

struct PowerModeSelector: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let maps: [PowerModeMapViewData]
    let select: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignSpace.extraSmall) {
                ForEach(maps) { map in
                    Button {
                        select(map.id)
                    } label: {
                        Text(map.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, Constants.horizontalPadding)
                            .frame(minWidth: Constants.minimumWidth, minHeight: Constants.minimumHeight)
                            .foregroundStyle(map.isSelected ? Color.white : DesignColor.primaryText)
                            .background {
                                Capsule()
                                    .fill(map.isSelected ? DesignColor.accent : DesignColor.controlSurface)
                            }
                            .overlay {
                                Capsule()
                                    .stroke(
                                        outlineColor(for: map),
                                        lineWidth: outlineWidth(for: map)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(map.accessibilityLabel)
                    .accessibilityAddTraits(map.isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, Constants.verticalPadding)
        }
        .scrollIndicators(.hidden)
    }

    private func outlineColor(for map: PowerModeMapViewData) -> Color {
        map.isSelected && differentiateWithoutColor
            ? DesignColor.primaryText
            : DesignColor.border
    }

    private func outlineWidth(for map: PowerModeMapViewData) -> CGFloat {
        map.isSelected && differentiateWithoutColor
            ? Constants.selectedOutlineWidth
            : Constants.outlineWidth
    }

    private enum Constants {
        static let horizontalPadding: CGFloat = 14
        static let minimumWidth: CGFloat = 54
        static let minimumHeight: CGFloat = 44
        static let outlineWidth: CGFloat = 1
        static let selectedOutlineWidth: CGFloat = 3
        static let verticalPadding: CGFloat = 2
    }
}
