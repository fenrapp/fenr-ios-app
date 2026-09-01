import BikeDomain

struct VehiclePowerModeRefreshRequest: Equatable, Sendable {
    let mapIndex: Int
    let needsBaseConfiguration: Bool
    let needsTractionControlConfiguration: Bool
}

extension LiveVehicleSessionService {
    func updatePowerModeRefresh(for telemetry: BikeTelemetry) {
        guard case .receivingTelemetry = connection.state else { return }
        guard let mapIndex = telemetry.mode.powerModeConfigurationIndex else {
            visitedPowerModeIndex = nil
            didAttemptPowerModeBaseRefresh = false
            didAttemptPowerModeTractionRefresh = false
            return
        }
        if visitedPowerModeIndex != mapIndex {
            visitedPowerModeIndex = mapIndex
            didAttemptPowerModeBaseRefresh = false
            didAttemptPowerModeTractionRefresh = false
        }

        let configuration = telemetry.powerModeConfigurations[mapIndex]
        let request = VehiclePowerModeRefreshRequest(
            mapIndex: mapIndex,
            needsBaseConfiguration: configuration?.hasBaseConfiguration != true
                && !didAttemptPowerModeBaseRefresh,
            needsTractionControlConfiguration: configuration?.hasTractionControlConfiguration != true
                && !didAttemptPowerModeTractionRefresh
        )
        guard request.needsBaseConfiguration || request.needsTractionControlConfiguration else { return }
        didAttemptPowerModeBaseRefresh = didAttemptPowerModeBaseRefresh
            || request.needsBaseConfiguration
        didAttemptPowerModeTractionRefresh = didAttemptPowerModeTractionRefresh
            || request.needsTractionControlConfiguration
        pendingPowerModeRefresh = request
        startPendingPowerModeRefreshIfNeeded()
    }

    func resetPowerModeRefresh() {
        powerModeRefreshGeneration &+= 1
        visitedPowerModeIndex = nil
        pendingPowerModeRefresh = nil
        powerModeRefreshTask?.cancel()
        powerModeRefreshTask = nil
        didAttemptPowerModeBaseRefresh = false
        didAttemptPowerModeTractionRefresh = false
    }
}

private extension LiveVehicleSessionService {
    func startPendingPowerModeRefreshIfNeeded() {
        guard powerModeRefreshTask == nil,
              let request = pendingPowerModeRefresh
        else { return }
        pendingPowerModeRefresh = nil
        let generation = powerModeRefreshGeneration
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
            await self?.finishPowerModeRefresh(generation: generation)
        }
    }

    func finishPowerModeRefresh(generation: Int) {
        guard generation == powerModeRefreshGeneration else { return }
        powerModeRefreshTask = nil
        startPendingPowerModeRefreshIfNeeded()
    }
}
