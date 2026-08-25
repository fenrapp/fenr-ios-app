import SwiftUI

struct DashboardCenterCard: View {
    let activeCard: RideDashboardViewState.CenterCard
    let speedometer: DashboardSpeedometerViewData
    let charging: ChargingDashboardViewState
    let referenceSize: CGSize
    let reduceMotion: Bool
    let setChargePowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void

    var body: some View {
        DashboardCardContainer(
            activeCard: activeCard,
            reduceMotion: reduceMotion
        ) {
            cardContent
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch activeCard {
        case .speedometer:
            DashboardSpeedometer(
                state: speedometer,
                referenceSize: referenceSize
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .charging:
            DashboardChargingCard(
                viewState: charging,
                setPowerLimit: setChargePowerLimit,
                setChargeTarget: setChargeTarget
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
