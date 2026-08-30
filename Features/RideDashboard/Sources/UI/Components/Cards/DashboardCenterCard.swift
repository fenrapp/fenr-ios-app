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
    let bikeLock: BikeLockCardViewState
    let bikeLockSecurityOptions: [BikeLockSecurityOptionViewData]
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
    let performBikeLockAction: () -> Void
    let configureBikeLock: (String, String) -> Void
    let submitBikeLockPIN: (String) -> Void
    let dismissBikeLockSheet: () -> Void

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
                cards: visibleRidingCards,
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
            speedometerCard
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .bikeLock:
            bikeLockCard
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

    private var visibleRidingCards: [RidingDashboardCard] {
        cardLayout.ridingCards.filter { $0 != .bikeLock || bikeLock.isAvailable }
    }

    private var speedometerCard: some View {
        DashboardSpeedometer(
            state: speedometer,
            showsSourceIndicator: showsSpeedSourceIndicator,
            referenceSize: referenceSize
        )
        .overlay(alignment: .bottom) {
            if bikeLock.isLocked {
                DashboardBikeLockStatusBadge()
                    .padding(.bottom, Constants.bikeLockBadgeBottomPadding)
                    .transition(.scale(scale: Constants.bikeLockBadgeTransitionScale).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(speedometerAccessibilityLabel)
        .animation(.easeInOut(duration: Constants.bikeLockBadgeAnimationDuration), value: bikeLock.isLocked)
    }

    private var speedometerAccessibilityLabel: String {
        guard bikeLock.isLocked else { return speedometer.accessibilityLabel }
        return "\(speedometer.accessibilityLabel), bike locked"
    }

    private var bikeLockCard: some View {
        DashboardBikeLockCard(
            viewState: bikeLock,
            securityOptions: bikeLockSecurityOptions,
            performPrimaryAction: performBikeLockAction,
            configure: configureBikeLock,
            submitPIN: submitBikeLockPIN,
            dismissSheet: dismissBikeLockSheet
        )
    }

    private enum Constants {
        static let bikeLockBadgeBottomPadding: CGFloat = 28
        static let bikeLockBadgeTransitionScale = 0.94
        static let bikeLockBadgeAnimationDuration = 0.18
    }
}
