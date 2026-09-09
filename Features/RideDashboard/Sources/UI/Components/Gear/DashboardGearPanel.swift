import DesignSystem
import SwiftUI

struct DashboardGearPanel: View {
    let state: DashboardGearViewData

    var body: some View {
        chip
            .overlay(alignment: .topTrailing) {
                if state.showsAdvancedCurve {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: Constants.advancedIconSize, weight: .semibold))
                        .frame(width: Constants.advancedCutoutSize, height: Constants.advancedCutoutSize)
                        .foregroundStyle(tint)
                        .offset(x: -Constants.advancedInset, y: Constants.advancedVerticalOffset)
                        .accessibilityLabel(.rideDashboardAdvancedCurveAccessibility)
                }
            }
            .accessibilityElement(children: .combine)
    }

    private var chip: some View {
        gearValue
            .frame(width: Constants.width, height: Constants.height)
            .background {
                Capsule()
                    .fill(tint.opacity(Constants.backgroundOpacity))
            }
            .overlay {
                Capsule()
                    .strokeBorder(tint, lineWidth: Constants.outlineWidth)
                    .mask {
                        Rectangle()
                            .overlay(alignment: .topTrailing) {
                                if state.showsAdvancedCurve {
                                    Rectangle()
                                        .frame(
                                            width: Constants.advancedCutoutSize,
                                            height: Constants.advancedCutoutSize
                                        )
                                        .offset(x: -Constants.advancedInset, y: Constants.advancedVerticalOffset)
                                        .blendMode(.destinationOut)
                                }
                            }
                            .compositingGroup()
                    }
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
        case .text: state.showsAdvancedCurve ? DesignColor.warning : DesignColor.positive
        }
    }

    private enum Constants {
        static let advancedIconSize: CGFloat = 20
        static let advancedCutoutSize: CGFloat = 24
        static let advancedInset: CGFloat = 10
        static let advancedVerticalOffset: CGFloat = -10
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
