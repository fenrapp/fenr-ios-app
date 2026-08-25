import DesignSystem
import SwiftUI

struct DashboardGearPanel: View {
    let state: DashboardGearViewData

    var body: some View {
        VStack(spacing: .zero) {
            Text("GEAR")
                .font(.system(size: Constants.titleFontSize, weight: .semibold))
                .foregroundStyle(.secondary)
            gearValue
                .frame(maxWidth: .infinity, minHeight: Constants.valueFontSize)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private var gearValue: some View {
        Group {
            switch state.display {
            case let .text(value):
                Text(value)
                    .font(.system(size: Constants.valueFontSize, weight: .medium, design: .rounded))
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
        .foregroundStyle(state.isActive ? DesignColor.positive : Color.primary)
    }

    private enum Constants {
        static let titleFontSize: CGFloat = 16
        static let valueFontSize: CGFloat = 73
        static let minimumScaleFactor = 0.65
        static let crawlIconSize: CGFloat = 57
        static let reverseArrowSize: CGFloat = 22
        static let reverseArrowVerticalOffset: CGFloat = -2
        static let reverseArrowHorizontalOffset: CGFloat = -8
    }
}
