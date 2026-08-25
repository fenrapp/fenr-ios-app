import DesignSystem
import SwiftUI

struct RideDashboardLayout {
    let isCompact: Bool
    let horizontalContentPadding: CGFloat
    let verticalContentPadding: CGFloat
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let bottomMetricsHeight: CGFloat
    let clockTopInset: CGFloat
    let clockHeight: CGFloat
    let clockToInstrumentSpacing: CGFloat
    let gaugeToIndicatorSpacing: CGFloat
    let indicatorToBottomMetricsSpacing: CGFloat

    init(size: CGSize, displaysBottomMetrics: Bool = false) {
        let compact = size.height < Constants.compactHeight
        isCompact = compact
        horizontalContentPadding = DesignSpace.medium
        verticalContentPadding = DesignSpace.extraSmall
        contentWidth = max(.zero, size.width - (horizontalContentPadding * 2))
        contentHeight = max(.zero, size.height - (verticalContentPadding * 2))
        bottomMetricsHeight = displaysBottomMetrics
            ? (compact ? Constants.compactBottomMetricsHeight : Constants.regularBottomMetricsHeight)
            : .zero
        clockTopInset = displaysBottomMetrics && compact ? .zero : Constants.clockTopInset
        clockHeight = displaysBottomMetrics && compact
            ? Constants.compactClockHeight
            : Constants.clockHeight
        clockToInstrumentSpacing = displaysBottomMetrics && compact
            ? .zero
            : Constants.clockToInstrumentSpacing
        gaugeToIndicatorSpacing = displaysBottomMetrics && compact
            ? .zero
            : Constants.gaugeToIndicatorSpacing
        indicatorToBottomMetricsSpacing = displaysBottomMetrics && compact
            ? .zero
            : Constants.indicatorToBottomMetricsSpacing
    }

    var minimumSideRegionWidth: CGFloat {
        isCompact ? Constants.compactSideMetricsWidth : Constants.regularSideMetricsWidth
    }

    var usesCompactSideMetrics: Bool {
        sideRegionWidth < Constants.regularSideMetricsWidth || isCompact
    }

    var instrumentWidth: CGFloat {
        let maximumInstrumentHeight = max(
            .zero,
            contentHeight - Constants.clockTopInset - Constants.clockHeight - Constants.clockToInstrumentSpacing
        )
        let availableWidth = contentWidth
            - (minimumSideRegionWidth * 2)
            - (Constants.sideToInstrumentSpacing * 2)
        let availableHeight = maximumInstrumentHeight
            - Constants.indicatorRailHeight
            - Constants.gaugeToIndicatorSpacing
        return max(
            .zero,
            min(
                contentWidth * Constants.landscapeSpeedRegionRatio,
                Constants.speedometerMaximumWidth,
                availableWidth,
                availableHeight * Constants.gaugeAspectRatio
            )
        )
    }

    var sideRegionWidth: CGFloat {
        max(.zero, (contentWidth - instrumentWidth - (Constants.sideToInstrumentSpacing * 2)) / 2)
    }

    enum Constants {
        static let speedometerMaximumWidth: CGFloat = 816
        static let regularSideMetricsWidth: CGFloat = 240
        static let compactSideMetricsWidth: CGFloat = 128
        static let sideToInstrumentSpacing: CGFloat = 8
        static let compactHeight: CGFloat = 450
        static let landscapeSpeedRegionRatio = 0.72
        static let gaugeAspectRatio: CGFloat = 2
        static let clockTopInset: CGFloat = DesignSpace.medium
        static let clockHeight: CGFloat = 32
        static let compactClockHeight: CGFloat = 24
        static let clockToInstrumentSpacing: CGFloat = DesignSpace.extraSmall
        static let indicatorRailHeight: CGFloat = 39
        static let gaugeToIndicatorSpacing: CGFloat = 8
        static let indicatorToBottomMetricsSpacing: CGFloat = 8
        static let compactBottomMetricsHeight: CGFloat = 40
        static let regularBottomMetricsHeight: CGFloat = 62
        static let liveTransitionScale = 0.98
        static let liveTransitionResponse = 0.35
        static let liveTransitionDamping = 0.86
        static let settingsIconSize: CGFloat = 20
    }
}
