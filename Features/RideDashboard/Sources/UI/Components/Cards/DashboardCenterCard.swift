import SwiftUI

struct DashboardCenterCard: View {
    let centerMode: RideDashboardViewState.CenterMode
    @Binding var selectedRidingCard: RidingDashboardCard
    let speedometer: DashboardSpeedometerViewData
    let showsSpeedSourceIndicator: Bool
    let currentTrip: DashboardCurrentTripViewData
    @Binding var selectedCurrentTripPage: CurrentTripDashboardPage
    let tripStatistics: DashboardTripStatisticsViewData
    let charging: ChargingDashboardViewState
    let referenceSize: CGSize
    let reduceMotion: Bool
    let toggleCurrentTripPause: () -> Void
    let resetCurrentTrip: () -> Void
    let setChargePowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void

    var body: some View {
        DashboardCardContainer(
            activeCard: centerMode,
            reduceMotion: reduceMotion
        ) {
            centerContent
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        switch centerMode {
        case .riding:
            DashboardRidingCardDeck(
                cards: RidingDashboardCard.allCases,
                selection: $selectedRidingCard,
                reduceMotion: reduceMotion
            ) { card in
                ridingCard(card)
            }
        case .charging:
            DashboardChargingCard(
                viewState: charging,
                setPowerLimit: setChargePowerLimit,
                setChargeTarget: setChargeTarget
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func ridingCard(_ card: RidingDashboardCard) -> some View {
        switch card {
        case .speedometer:
            DashboardSpeedometer(
                state: speedometer,
                showsSourceIndicator: showsSpeedSourceIndicator,
                referenceSize: referenceSize
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .currentTrip:
            DashboardCurrentTripPager(
                selection: $selectedCurrentTripPage,
                currentTrip: currentTrip,
                statistics: tripStatistics,
                reduceMotion: reduceMotion,
                togglePause: toggleCurrentTripPause,
                reset: resetCurrentTrip
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
