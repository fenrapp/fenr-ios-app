import SwiftUI

struct DashboardShell<
    SideMetrics: View,
    Gear: View,
    Instrument: View,
    Indicators: View,
    BottomMetrics: View
>: View {
    let layout: RideDashboardLayout
    @ViewBuilder let sideMetrics: () -> SideMetrics
    @ViewBuilder let gear: () -> Gear
    @ViewBuilder let instrument: () -> Instrument
    @ViewBuilder let indicators: () -> Indicators
    @ViewBuilder let bottomMetrics: () -> BottomMetrics

    var body: some View {
        ZStack {
            instrumentColumn
            HStack(spacing: RideDashboardLayout.Constants.sideToInstrumentSpacing) {
                sideMetrics()
                    .frame(width: layout.sideRegionWidth, alignment: .trailing)
                Color.clear
                    .frame(width: layout.instrumentWidth)
                gear()
                    .frame(width: layout.sideRegionWidth, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var instrumentColumn: some View {
        let gaugeHeight = layout.instrumentWidth / RideDashboardLayout.Constants.gaugeAspectRatio

        return VStack(spacing: layout.clockToInstrumentSpacing) {
            DashboardClock()
                .frame(height: layout.clockHeight, alignment: .bottom)
                .padding(.top, layout.clockTopInset)
                .frame(width: layout.instrumentWidth, alignment: .center)
            VStack(spacing: .zero) {
                instrument()
                    .frame(width: layout.instrumentWidth, height: gaugeHeight)
                    .layoutPriority(1)
                Spacer()
                    .frame(height: layout.gaugeToIndicatorSpacing)
                indicators()
                    .frame(
                        width: layout.instrumentWidth,
                        height: RideDashboardLayout.Constants.indicatorRailHeight
                    )
                if layout.bottomMetricsHeight > .zero {
                    Spacer()
                        .frame(height: layout.indicatorToBottomMetricsSpacing)
                    bottomMetrics()
                        .frame(width: layout.instrumentWidth, height: layout.bottomMetricsHeight)
                }
            }
            .frame(
                width: layout.instrumentWidth,
                height: gaugeHeight
                    + layout.gaugeToIndicatorSpacing
                    + RideDashboardLayout.Constants.indicatorRailHeight
                    + (layout.bottomMetricsHeight > .zero
                        ? layout.indicatorToBottomMetricsSpacing
                            + layout.bottomMetricsHeight
                        : .zero)
            )
            Spacer(minLength: .zero)
        }
        .frame(width: layout.contentWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
