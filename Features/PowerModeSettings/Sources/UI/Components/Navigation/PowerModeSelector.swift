import DesignSystem
import SwiftUI

struct PowerModeSelector: View {
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
                                    .fill(map.isSelected ? DesignColor.accent : DesignColor.groupedSurface)
                            }
                            .overlay {
                                Capsule()
                                    .stroke(DesignColor.border, lineWidth: Constants.outlineWidth)
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

    private enum Constants {
        static let horizontalPadding: CGFloat = 14
        static let minimumWidth: CGFloat = 54
        static let minimumHeight: CGFloat = 38
        static let outlineWidth: CGFloat = 1
        static let verticalPadding: CGFloat = 2
    }
}
