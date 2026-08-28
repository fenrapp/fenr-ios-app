import DesignSystem
import SwiftUI

struct DashboardGearPanel: View {
    let state: DashboardGearViewData

    var body: some View {
        gearValue
            .frame(width: Constants.width, height: Constants.height)
            .background {
                Capsule()
                    .fill(tint.opacity(Constants.backgroundOpacity))
            }
            .overlay {
                Capsule()
                    .stroke(tint, lineWidth: Constants.outlineWidth)
            }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private var gearValue: some View {
        Group {
            switch state.display {
            case let .text(value):
                Text(value)
                    .font(.system(
                        size: value.count > Constants.compactTextThreshold
                            ? Constants.nameFontSize
                            : Constants.valueFontSize,
                        weight: .medium,
                        design: .rounded
                    ))
                    .lineLimit(1)
                    .minimumScaleFactor(Constants.minimumScaleFactor)
            case .crawlForward:
                Image(systemName: "tortoise.fill")
                    .font(.system(size: Constants.crawlIconSize, weight: .medium))
            case .crawlReverse:
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "tortoise.fill")
                        .font(.system(size: Constants.crawlIconSize, weight: .medium))
                        .scaleEffect(x: -1, y: 1)
                    Image(systemName: "arrow.backward")
                        .font(.system(size: Constants.reverseArrowSize, weight: .bold))
                        .padding(.top, Constants.reverseArrowVerticalOffset)
                        .padding(.trailing, Constants.reverseArrowHorizontalOffset)
                }
            }
        }
        .foregroundStyle(tint)
    }

    private var tint: Color {
        guard state.isActive else { return DesignColor.secondaryText }
        return switch state.display {
        case .crawlForward: DesignColor.informational
        case .crawlReverse: DesignColor.warning
        case .text: DesignColor.positive
        }
    }

    private enum Constants {
        static let width: CGFloat = 112
        static let height: CGFloat = 60
        static let outlineWidth: CGFloat = 2.75
        static let backgroundOpacity = 0.08
        static let valueFontSize: CGFloat = 34
        static let nameFontSize: CGFloat = 20
        static let compactTextThreshold = 2
        static let minimumScaleFactor = 0.65
        static let crawlIconSize: CGFloat = 32
        static let reverseArrowSize: CGFloat = 14
        static let reverseArrowVerticalOffset: CGFloat = -2
        static let reverseArrowHorizontalOffset: CGFloat = -6
    }
}
