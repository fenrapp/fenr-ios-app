import BikeDomain

struct VehiclePowerModeRefreshRequest: Equatable, Sendable {
    let mapIndex: Int
    let needsBaseConfiguration: Bool
    let needsTractionControlConfiguration: Bool
}

extension LiveVehicleSessionService {
    func updatePowerModeRefresh(for telemetry: BikeTelemetry) {
        guard let mapIndex = telemetry.mode.powerModeConfigurationIndex else {
            visitedPowerModeIndex = nil
            return
        }
        guard visitedPowerModeIndex != mapIndex else { return }
        visitedPowerModeIndex = mapIndex

        let configuration = telemetry.powerModeConfigurations[mapIndex]
        let request = VehiclePowerModeRefreshRequest(
            mapIndex: mapIndex,
            needsBaseConfiguration: configuration?.hasBaseConfiguration != true,
            needsTractionControlConfiguration: configuration?.hasTractionControlConfiguration != true
        )
        guard request.needsBaseConfiguration || request.needsTractionControlConfiguration else { return }
        pendingPowerModeRefresh = request
        startPendingPowerModeRefreshIfNeeded()
    }

    func resetPowerModeRefresh() {
        visitedPowerModeIndex = nil
        pendingPowerModeRefresh = nil
        powerModeRefreshTask?.cancel()
        powerModeRefreshTask = nil
    }
}

private extension LiveVehicleSessionService {
    func startPendingPowerModeRefreshIfNeeded() {
        guard powerModeRefreshTask == nil,
              let request = pendingPowerModeRefresh
        else { return }
        pendingPowerModeRefresh = nil
        let refreshBase = useCases.refreshPowerModeConfiguration
        let refreshTraction = useCases.refreshTractionControlConfiguration
        powerModeRefreshTask = Task { [weak self] in
            if request.needsBaseConfiguration, let refreshBase {
                try? await refreshBase.execute(mapIndex: request.mapIndex)
            }
            if !Task.isCancelled,
               request.needsTractionControlConfiguration,
               let refreshTraction {
                try? await refreshTraction.execute(mapIndex: request.mapIndex)
            }
            await self?.finishPowerModeRefresh()
        }
    }

    func finishPowerModeRefresh() {
        powerModeRefreshTask = nil
        startPendingPowerModeRefreshIfNeeded()
    }
}
