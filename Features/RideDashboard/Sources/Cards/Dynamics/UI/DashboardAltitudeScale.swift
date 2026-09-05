import DesignSystem
import SwiftUI

struct DashboardAltitudeScale: View {
    let ticks: [DashboardAltitudeViewData.Tick]
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(ticks) { tick in
                    HStack(spacing: DesignSpace.extraSmall) {
                        Capsule()
                            .fill(tick.label == nil ? DesignColor.inactive : DesignColor.secondaryText)
                            .frame(
                                width: tick.label == nil ? Constants.minorWidth : Constants.majorWidth,
                                height: Constants.tickHeight
                            )
                        if let label = tick.label {
                            Text(verbatim: label)
                                .font(.system(size: Constants.labelFontSize, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(DesignColor.secondaryText)
                        }
                    }
                    .frame(height: Constants.labelHeight)
                    .offset(y: proxy.size.height * tick.position - Constants.labelHeight / 2)
                }
                Rectangle()
                    .fill(DesignColor.informational)
                    .frame(width: Constants.indicatorWidth, height: Constants.indicatorHeight)
                    .offset(y: proxy.size.height / 2 - Constants.indicatorHeight / 2)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: Constants.animationDuration), value: ticks)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private enum Constants {
        static let minorWidth: CGFloat = 8
        static let majorWidth: CGFloat = 14
        static let tickHeight: CGFloat = 2
        static let labelFontSize: CGFloat = 11
        static let labelHeight: CGFloat = 18
        static let indicatorWidth: CGFloat = 20
        static let indicatorHeight: CGFloat = 3
        static let animationDuration = 0.25
    }
}
