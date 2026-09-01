import BikeDomain

public actor VehiclePowerModeRefreshCoordinator {
    private struct Request: Equatable, Sendable {
        let mapIndex: Int
        let needsBaseConfiguration: Bool
        let needsTractionControlConfiguration: Bool
    }

    private let refreshPowerModeConfiguration: RefreshBikePowerModeConfigurationUseCase?
    private let refreshTractionControlConfiguration: RefreshBikeTractionControlConfigurationUseCase?
    private var refreshTask: Task<Void, Never>?
    private var generation = 0
    private var pendingRequest: Request?
    private var visitedMapIndex: Int?
    private var didAttemptBaseRefresh = false
    private var didAttemptTractionRefresh = false

    public init(
        refreshPowerModeConfiguration: RefreshBikePowerModeConfigurationUseCase?,
        refreshTractionControlConfiguration: RefreshBikeTractionControlConfigurationUseCase?
    ) {
        self.refreshPowerModeConfiguration = refreshPowerModeConfiguration
        self.refreshTractionControlConfiguration = refreshTractionControlConfiguration
    }

    deinit {
        refreshTask?.cancel()
    }

    func update(telemetry: BikeTelemetry, isReceivingTelemetry: Bool) {
        guard isReceivingTelemetry else { return }
        guard let mapIndex = telemetry.mode.powerModeConfigurationIndex else {
            visitedMapIndex = nil
            didAttemptBaseRefresh = false
            didAttemptTractionRefresh = false
            return
        }
        if visitedMapIndex != mapIndex {
            visitedMapIndex = mapIndex
            didAttemptBaseRefresh = false
            didAttemptTractionRefresh = false
        }

        let configuration = telemetry.powerModeConfigurations[mapIndex]
        let request = Request(
            mapIndex: mapIndex,
            needsBaseConfiguration: configuration?.hasBaseConfiguration != true
                && !didAttemptBaseRefresh,
            needsTractionControlConfiguration: configuration?.hasTractionControlConfiguration != true
                && !didAttemptTractionRefresh
        )
        guard request.needsBaseConfiguration || request.needsTractionControlConfiguration else {
            return
        }
        didAttemptBaseRefresh = didAttemptBaseRefresh || request.needsBaseConfiguration
        didAttemptTractionRefresh = didAttemptTractionRefresh
            || request.needsTractionControlConfiguration
        pendingRequest = request
        startPendingRequestIfNeeded()
    }

    func reset() {
        generation &+= 1
        visitedMapIndex = nil
        pendingRequest = nil
        refreshTask?.cancel()
        refreshTask = nil
        didAttemptBaseRefresh = false
        didAttemptTractionRefresh = false
    }
}

private extension VehiclePowerModeRefreshCoordinator {
    func startPendingRequestIfNeeded() {
        guard refreshTask == nil, let request = pendingRequest else { return }
        pendingRequest = nil
        let generation = generation
        let refreshBase = refreshPowerModeConfiguration
        let refreshTraction = refreshTractionControlConfiguration
        refreshTask = Task { [weak self] in
            guard !Task.isCancelled,
                  await self?.isCurrent(generation: generation) == true
            else { return }
            if request.needsBaseConfiguration, let refreshBase {
                try? await refreshBase.execute(mapIndex: request.mapIndex)
            }
            guard !Task.isCancelled,
                  await self?.isCurrent(generation: generation) == true
            else { return }
            if request.needsTractionControlConfiguration, let refreshTraction {
                try? await refreshTraction.execute(mapIndex: request.mapIndex)
            }
            guard !Task.isCancelled else { return }
            await self?.finish(generation: generation)
        }
    }

    func isCurrent(generation: Int) -> Bool {
        generation == self.generation
    }

    func finish(generation: Int) {
        guard generation == self.generation else { return }
        refreshTask = nil
        startPendingRequestIfNeeded()
    }
}
