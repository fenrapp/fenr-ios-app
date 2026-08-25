import CoreGraphics
@testable import RideDashboard
import Testing

@Suite("Ride dashboard layout")
struct RideDashboardLayoutTests {
    @Test("Ride and charging gauges use the same compact landscape width")
    func sharesGaugeWidthAcrossDashboardModes() {
        let size = CGSize(width: 932, height: 430)
        let charging = RideDashboardLayout(size: size)
        let riding = RideDashboardLayout(size: size, displaysBottomMetrics: true)

        #expect(riding.instrumentWidth == charging.instrumentWidth)
    }

    @Test("Compact power mode strip fits without shrinking the gauge")
    func fitsPowerModeStripInCompactLandscape() {
        let layout = RideDashboardLayout(
            size: CGSize(width: 932, height: 430),
            displaysBottomMetrics: true
        )
        let gaugeHeight = layout.instrumentWidth / RideDashboardLayout.Constants.gaugeAspectRatio
        let occupiedHeight = layout.clockTopInset
            + layout.clockHeight
            + layout.clockToInstrumentSpacing
            + gaugeHeight
            + layout.gaugeToIndicatorSpacing
            + RideDashboardLayout.Constants.indicatorRailHeight
            + layout.indicatorToBottomMetricsSpacing
            + layout.bottomMetricsHeight

        #expect(occupiedHeight <= layout.contentHeight)
    }
}
