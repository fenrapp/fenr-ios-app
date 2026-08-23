import SwiftUI

struct DashboardShell<SideMetrics: View, Gear: View, Instrument: View, Indicators: View>: View {
    let layout: RideDashboardLayout
    @ViewBuilder let sideMetrics: () -> SideMetrics
    @ViewBuilder let gear: () -> Gear
    @ViewBuilder let instrument: () -> Instrument
    @ViewBuilder let indicators: () -> Indicators

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

        return VStack(spacing: RideDashboardLayout.Constants.clockToInstrumentSpacing) {
            DashboardClock()
                .padding(.top, RideDashboardLayout.Constants.clockTopInset)
                .frame(width: layout.instrumentWidth, alignment: .center)
            VStack(spacing: RideDashboardLayout.Constants.gaugeToIndicatorSpacing) {
                instrument()
                    .frame(width: layout.instrumentWidth, height: gaugeHeight)
                    .layoutPriority(1)
                indicators()
                    .frame(
                        width: layout.instrumentWidth,
                        height: RideDashboardLayout.Constants.indicatorRailHeight
                    )
            }
            .frame(
                width: layout.instrumentWidth,
                height: gaugeHeight
                    + RideDashboardLayout.Constants.gaugeToIndicatorSpacing
                    + RideDashboardLayout.Constants.indicatorRailHeight
            )
            Spacer(minLength: .zero)
        }
        .frame(width: layout.contentWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
