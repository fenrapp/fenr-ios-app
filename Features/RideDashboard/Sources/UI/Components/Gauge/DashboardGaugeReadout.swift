import DesignSystem
import SwiftUI

struct DashboardGaugeReadout: View {
    let mode: DashboardGaugeMode
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: readoutSpacing) {
                if let title = mode.title {
                    Text(title)
                        .font(mode.isShowingEstimatedTime ? .title3.weight(.semibold) : .caption.weight(.semibold))
                        .tracking(mode.isShowingEstimatedTime ? .zero : Constants.statusTracking)
                        .monospacedDigit()
                        .foregroundStyle(DesignColor.secondaryText)
                }
                Color.clear
                    .frame(height: valueFontSize(for: proxy.size))
                    .overlay {
                        valueReadout(
                            fontSize: valueFontSize(for: proxy.size),
                            percentageSignFontSize: percentageSignFontSize(for: proxy.size)
                        )
                    }
                if let unit = mode.unit {
                    Text(unit)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DesignColor.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .offset(y: proxy.size.height * Constants.verticalOffsetRatio)
        }
    }

    @ViewBuilder
    private func valueReadout(fontSize: CGFloat, percentageSignFontSize: CGFloat) -> some View {
        switch mode {
        case .speed:
            Color.clear
                .animatedDashboardNumber(mode.value, formatter: mode.displayValue)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(DesignColor.primaryText)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : Constants.valueAnimation, value: mode.value)
        case .charging:
            Color.clear
                .animatedDashboardNumber(mode.value, formatter: mode.displayValue)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .overlay(alignment: .trailing) {
                    Text("%")
                        .font(.system(size: percentageSignFontSize, weight: .medium, design: .rounded))
                        .offset(
                            x: percentageSignFontSize * Constants.percentageSignOffsetMultiplier
                                + Constants.percentageSignSpacing
                        )
                }
                .foregroundStyle(DesignColor.primaryText)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : Constants.valueAnimation, value: mode.value)
        }
    }

    private func valueFontSize(for size: CGSize) -> CGFloat {
        let baseFontSize = baseValueFontSize(for: size)
        guard case .charging = mode else { return baseFontSize }
        return baseFontSize * Constants.chargingValueScale
    }

    private func percentageSignFontSize(for size: CGSize) -> CGFloat {
        baseValueFontSize(for: size) * Constants.percentageSignScale * Constants.percentageSignIncrease
    }

    private func baseValueFontSize(for size: CGSize) -> CGFloat {
        let ratio = switch mode {
        case .speed: Constants.speedValueWidthRatio
        case .charging: Constants.chargingValueWidthRatio
        }
        return min(
            max(size.width * ratio, Constants.minimumValueFontSize),
            Constants.maximumValueFontSize
        )
    }

    private var readoutSpacing: CGFloat {
        if case .charging = mode { return Constants.chargingTitleSpacing }
        return Constants.readoutSpacing
    }

    private enum Constants {
        static let readoutSpacing: CGFloat = 2
        static let chargingTitleSpacing: CGFloat = 16
        static let speedValueWidthRatio: CGFloat = 0.19
        static let chargingValueWidthRatio: CGFloat = 0.18
        static let minimumValueFontSize: CGFloat = 48
        static let maximumValueFontSize: CGFloat = 96
        static let chargingValueScale: CGFloat = 1.3
        static let percentageSignScale: CGFloat = 0.3
        static let percentageSignIncrease: CGFloat = 1.2
        static let percentageSignSpacing: CGFloat = 2
        static let percentageSignOffsetMultiplier: CGFloat = 0.75
        static let verticalOffsetRatio: CGFloat = 0.25
        static let statusTracking: CGFloat = 4
        static let valueAnimation = Animation.spring(response: 0.52, dampingFraction: 0.82)
    }
}
