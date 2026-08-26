import DesignSystem
import SwiftUI

struct DashboardSpeedometer: View {
    let state: DashboardSpeedometerViewData
    private let showsSourceIndicator: Bool
    private let referenceSize: CGSize?
    @ScaledMetric(relativeTo: .body) private var dynamicTypeScale: CGFloat = 1

    init(
        state: DashboardSpeedometerViewData,
        showsSourceIndicator: Bool = true,
        referenceSize: CGSize? = nil
    ) {
        self.state = state
        self.showsSourceIndicator = showsSourceIndicator
        self.referenceSize = referenceSize
    }

    var body: some View {
        GeometryReader { proxy in
            let fontReferenceSize = referenceSize ?? proxy.size
            let valueFontSize = Self.valueFontSize(
                for: fontReferenceSize,
                availableSize: proxy.size,
                dynamicTypeScale: dynamicTypeScale
            )
            let unitFontSize = Self.unitFontSize(
                for: fontReferenceSize,
                availableSize: proxy.size,
                dynamicTypeScale: dynamicTypeScale
            )
            VStack(spacing: Constants.valueToUnitSpacing) {
                speedValue(fontSize: valueFontSize)
                    .overlay(alignment: .top) {
                        if showsSourceIndicator,
                           let sourceIndicator = state.sourceIndicator {
                            DashboardSpeedSourceChip(state: sourceIndicator)
                                .offset(y: -Constants.chipVerticalOffset)
                                .transition(
                                    .scale(scale: Constants.chipTransitionScale)
                                        .combined(with: .opacity)
                                )
                        }
                    }
                Text(state.unit)
                    .font(
                        .system(
                            size: unitFontSize,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .lineLimit(1)
                    .foregroundStyle(DesignColor.secondaryText)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
        .animation(.easeInOut(duration: Constants.chipAnimationDuration), value: state.sourceIndicator)
        .animation(.easeInOut(duration: Constants.chipAnimationDuration), value: showsSourceIndicator)
    }

    private func speedValue(fontSize: CGFloat) -> some View {
        Text(state.valueText)
            .font(
                .system(
                    size: fontSize,
                    weight: .medium,
                    design: .rounded
                )
            )
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(DesignColor.primaryText)
    }

    static func minimumContentWidth(
        for size: CGSize,
        dynamicTypeScale: CGFloat = 1
    ) -> CGFloat {
        baseValueFontSize(for: size) * dynamicTypeScale * Constants.maximumValueWidthRatio
            + Constants.valueHorizontalAllowance
    }

    private static func valueFontSize(
        for referenceSize: CGSize,
        availableSize: CGSize,
        dynamicTypeScale: CGFloat
    ) -> CGFloat {
        let desiredSize = baseValueFontSize(for: referenceSize) * dynamicTypeScale
        let maximumWidthSize = max(
            .zero,
            (availableSize.width - Constants.valueHorizontalAllowance)
                / Constants.maximumValueWidthRatio
        )
        let maximumHeightSize = availableSize.height * Constants.maximumValueHeightRatio
        return min(desiredSize, maximumWidthSize, maximumHeightSize)
    }

    private static func baseValueFontSize(for size: CGSize) -> CGFloat {
        min(size.width * Constants.valueWidthRatio, size.height * Constants.valueHeightRatio)
    }

    private static func unitFontSize(
        for referenceSize: CGSize,
        availableSize: CGSize,
        dynamicTypeScale: CGFloat
    ) -> CGFloat {
        let baseSize = min(
            referenceSize.width * Constants.unitWidthRatio,
            referenceSize.height * Constants.unitHeightRatio
        )
        return min(baseSize * dynamicTypeScale, availableSize.height * Constants.maximumUnitHeightRatio)
    }

    private enum Constants {
        static let valueToUnitSpacing: CGFloat = 4
        static let valueWidthRatio: CGFloat = 0.22
        static let valueHeightRatio: CGFloat = 0.46
        static let maximumValueWidthRatio: CGFloat = 1.85
        static let maximumValueHeightRatio: CGFloat = 0.78
        static let valueHorizontalAllowance: CGFloat = 16
        static let unitWidthRatio: CGFloat = 0.035
        static let unitHeightRatio: CGFloat = 0.075
        static let maximumUnitHeightRatio: CGFloat = 0.16
        static let chipVerticalOffset: CGFloat = 24
        static let chipTransitionScale = 0.92
        static let chipAnimationDuration = 0.16
    }
}
