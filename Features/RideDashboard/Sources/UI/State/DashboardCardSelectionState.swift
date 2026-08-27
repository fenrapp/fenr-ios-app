struct DashboardCardSelectionState: Equatable {
    var ridingCard = RidingDashboardCard.speedometer
    var currentTripPage = CurrentTripDashboardPage.current
    var efficiencyPage = EfficiencyDashboardPage.live

    func isSpeedometerVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .speedometer
    }

    func isCurrentTripVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .currentTrip
    }

    func isEfficiencyVisible(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        centerMode == .riding && ridingCard == .efficiency
    }

    func needsHiddenPageReset(in centerMode: RideDashboardViewState.CenterMode) -> Bool {
        (!isCurrentTripVisible(in: centerMode) && currentTripPage != .current)
            || (!isEfficiencyVisible(in: centerMode) && efficiencyPage != .live)
    }

    mutating func selectSpeedometer() {
        ridingCard = .speedometer
    }

    mutating func resetHiddenPages(in centerMode: RideDashboardViewState.CenterMode) {
        if !isCurrentTripVisible(in: centerMode) {
            currentTripPage = .current
        }
        if !isEfficiencyVisible(in: centerMode) {
            efficiencyPage = .live
        }
    }
}
