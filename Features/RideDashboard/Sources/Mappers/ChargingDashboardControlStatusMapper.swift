import ChargeControl

public struct ChargingDashboardControlStatusMapper: Sendable {
    public init() {}

    public func map(_ state: ChargeControlState) -> ChargingDashboardStatusViewData? {
        switch state.phase {
        case .updating: updatingStatus(for: state)
        case .failed: .init(
            text: rideDashboardLocalized(.rideDashboardChargingStatusUpdateFailed),
            systemImage: "exclamationmark.triangle.fill",
            emphasis: .failure,
            showsActivityIndicator: false
        )
        case .unavailable, .preparing, .ready: nil
        }
    }

    private func updatingStatus(for state: ChargeControlState) -> ChargingDashboardStatusViewData {
        let isPowerPending = state.confirmedWatts.map(Double.init) != state.selectedWatts
        let isTargetPending = state.confirmedTargetPercent.map(Double.init) != state.selectedTargetPercent

        return switch (isPowerPending, isTargetPending) {
        case (true, false): .init(
            text: rideDashboardLocalized(.rideDashboardChargingStatusUpdatingPower),
            systemImage: "bolt.fill",
            emphasis: .power,
            showsActivityIndicator: true
        )
        case (false, true): .init(
            text: rideDashboardLocalized(.rideDashboardChargingStatusUpdatingLimit),
            systemImage: "battery.100percent",
            emphasis: .target,
            showsActivityIndicator: true
        )
        case (true, true), (false, false): .init(
            text: rideDashboardLocalized(.rideDashboardChargingStatusUpdatingSettings),
            systemImage: "slider.horizontal.3",
            emphasis: .general,
            showsActivityIndicator: true
        )
        }
    }
}
