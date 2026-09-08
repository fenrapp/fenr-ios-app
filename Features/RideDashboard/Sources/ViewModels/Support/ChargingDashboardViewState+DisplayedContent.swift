extension ChargingDashboardViewState {
    func hasSameDisplayedContent(as other: Self) -> Bool {
        batteryPercent == other.batteryPercent
            && targetPercent == other.targetPercent
            && estimatedTimeRemaining == other.estimatedTimeRemaining
            && isBalancingAtFullCharge == other.isBalancingAtFullCharge
            && readout == other.readout
            && control == other.control
            && batteryTemperatureEmphasis == other.batteryTemperatureEmphasis
            && Self.sameMetricDisplay(maximumPower, other.maximumPower)
            && Self.sameMetricDisplay(chargingPower, other.chargingPower)
            && Self.sameMetricDisplay(reportedCurrent, other.reportedCurrent)
            && Self.sameMetricDisplay(batteryTemperature, other.batteryTemperature)
            && Self.sameMetricDisplay(activeBalancingCells, other.activeBalancingCells)
    }

    private static func sameMetricDisplay(_ lhs: DashboardMetricViewData, _ rhs: DashboardMetricViewData) -> Bool {
        lhs.valueText == rhs.valueText
            && lhs.unitText == rhs.unitText
            && (lhs.animationValue != nil) == (rhs.animationValue != nil)
    }
}
