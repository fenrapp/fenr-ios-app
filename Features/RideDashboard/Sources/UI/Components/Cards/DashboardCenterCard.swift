import SwiftUI

struct DashboardCenterCard: View {
    let centerMode: RideDashboardViewState.CenterMode
    let cardLayout: DashboardCardLayout
    @Binding var selectedRidingCard: RidingDashboardCard
    let speedometer: DashboardSpeedometerViewData
    let showsSpeedSourceIndicator: Bool
    let currentTrip: DashboardCurrentTripViewData
    @Binding var selectedCurrentTripPage: CurrentTripDashboardPage
    let tripStatistics: DashboardTripStatisticsViewData
    @Binding var selectedEfficiencyPage: EfficiencyDashboardPage
    let efficiency: DashboardEfficiencyViewData
    @Binding var selectedRangePage: RangeDashboardPage
    let range: DashboardRangeViewData
    @Binding var selectedSystemHealthPage: SystemHealthDashboardPage
    let systemHealth: DashboardSystemHealthViewData
    @Binding var selectedDynamicsPage: RideDynamicsDashboardPage
    let dynamics: DashboardRideDynamicsViewData
    let charging: ChargingDashboardViewState
    let referenceSize: CGSize
    let reduceMotion: Bool
    let toggleCurrentTripPause: () -> Void
    let resetCurrentTrip: () -> Void
    let calibrateDynamics: () -> Void
    let setChargePowerLimit: (Double) -> Void
    let setChargeTarget: (Double) -> Void
    let openNavigation: () -> Void
    let isNavigationActive: Bool

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
                cards: cardLayout.ridingCards,
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
        case .navigation:
            DashboardNavigationCard(
                isNavigationActive: isNavigationActive,
                openNavigation: openNavigation
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .currentTrip:
            DashboardCurrentTripPager(
                pages: cardLayout.currentTripPages,
                selection: $selectedCurrentTripPage,
                currentTrip: currentTrip,
                statistics: tripStatistics,
                reduceMotion: reduceMotion,
                togglePause: toggleCurrentTripPause,
                reset: resetCurrentTrip
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .efficiency:
            DashboardEfficiencyPager(
                pages: cardLayout.efficiencyPages,
                selection: $selectedEfficiencyPage,
                state: efficiency,
                reduceMotion: reduceMotion
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .range:
            DashboardRangePager(
                pages: cardLayout.rangePages,
                selection: $selectedRangePage,
                state: range,
                reduceMotion: reduceMotion
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .systemHealth:
            DashboardSystemHealthPager(
                pages: cardLayout.systemHealthPages,
                selection: $selectedSystemHealthPage,
                state: systemHealth,
                reduceMotion: reduceMotion
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .dynamics:
            DashboardRideDynamicsPager(
                pages: cardLayout.dynamicsPages,
                selection: $selectedDynamicsPage,
                state: dynamics,
                reduceMotion: reduceMotion,
                calibrate: calibrateDynamics
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
