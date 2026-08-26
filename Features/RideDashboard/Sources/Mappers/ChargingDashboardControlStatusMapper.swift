import ChargeControl

public struct ChargingDashboardControlStatusMapper: Sendable {
    public init() {}

    public func map(_ state: ChargeControlState) -> ChargingDashboardStatusViewData? {
        switch state.phase {
        case .updating: updatingStatus(for: state)
        case .failed: .init(
            text: "UPDATE FAILED",
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
            text: "UPDATING CHARGING POWER",
            systemImage: "bolt.fill",
            emphasis: .power,
            showsActivityIndicator: true
        )
        case (false, true): .init(
            text: "UPDATING CHARGE LIMIT",
            systemImage: "battery.100percent",
            emphasis: .target,
            showsActivityIndicator: true
        )
        case (true, true), (false, false): .init(
            text: "UPDATING CHARGE SETTINGS",
            systemImage: "slider.horizontal.3",
            emphasis: .general,
            showsActivityIndicator: true
        )
        }
    }
}
