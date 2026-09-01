import BikeDomain

extension LiveVehicleSessionService {
    func beginBatteryHealthMonitoring() {
        guard !isStopping,
              isReceivingTelemetry,
              !batteryHealthConsumers.isEmpty,
              batteryHealthStartTask == nil,
              batteryHealthStopTask == nil else {
            return
        }
        batteryHealthMonitoringGeneration &+= 1
        let generation = batteryHealthMonitoringGeneration
        batteryHealthStartGeneration = generation
        batteryHealthMonitoringState = .starting
        publish()
        let start = useCases.startBatteryHealthMonitoring
        batteryHealthStartTask = Task { [weak self] in
            let result: Result<Void, Error>
            do {
                try await start.execute()
                result = .success(())
            } catch {
                result = .failure(error)
            }
            await self?.finishBatteryHealthStart(
                result,
                generation: generation,
                wasCancelled: Task.isCancelled
            )
        }
    }

    func finishBatteryHealthStart(
        _ result: Result<Void, Error>,
        generation: Int,
        wasCancelled: Bool
    ) async {
        guard batteryHealthStartGeneration == generation else {
            if case .success = result {
                await useCases.stopBatteryHealthMonitoring.execute()
            }
            return
        }
        let isCurrentGeneration = generation == batteryHealthMonitoringGeneration
        let canActivate = isCurrentGeneration
            && !wasCancelled
            && !isStopping
            && isReceivingTelemetry
            && !batteryHealthConsumers.isEmpty

        if case .success = result, canActivate {
            batteryHealthStartTask = nil
            batteryHealthStartGeneration = nil
            batteryHealthMonitoringState = .active
            observeBatteryHealth()
            publish()
            return
        }

        if case .success = result {
            await useCases.stopBatteryHealthMonitoring.execute()
        }
        batteryHealthStartTask = nil
        batteryHealthStartGeneration = nil

        if isCurrentGeneration, case .failure(let error) = result,
           isReceivingTelemetry, !batteryHealthConsumers.isEmpty, !isStopping {
            batteryHealthMonitoringState = .failed(String(describing: error))
        } else {
            batteryHealthMonitoringState = batteryHealthConsumers.isEmpty
                ? .inactive
                : batteryHealthMonitoringState
        }
        if !isReceivingTelemetry || wasCancelled || !isCurrentGeneration {
            batteryHealthMonitoringState = .inactive
        }
        publish()
        if !isStopping,
           isReceivingTelemetry,
           !batteryHealthConsumers.isEmpty,
           !isCurrentGeneration {
            beginBatteryHealthMonitoring()
        }
    }

    func scheduleBatteryHealthStop() {
        batteryHealthTask?.cancel()
        batteryHealthTask = nil
        batteryHealthMonitoringState = .inactive
        batteryHealth = .init()
        publish()
        guard batteryHealthStopTask == nil else { return }
        let stop = useCases.stopBatteryHealthMonitoring
        batteryHealthStopTask = Task { [weak self] in
            await stop.execute()
            await self?.finishBatteryHealthStop()
        }
    }

    private func finishBatteryHealthStop() {
        batteryHealthStopTask = nil
        if !isStopping, isReceivingTelemetry, !batteryHealthConsumers.isEmpty {
            beginBatteryHealthMonitoring()
        }
    }

    func invalidateBatteryHealthMonitoringForConnectionLoss() {
        batteryHealthMonitoringGeneration &+= 1
        batteryHealthStartTask?.cancel()
        batteryHealthTask?.cancel()
        batteryHealthTask = nil
        batteryHealthMonitoringState = .inactive
        batteryHealth = .init()
    }

    func resumeBatteryHealthMonitoringIfNeeded() {
        guard !batteryHealthConsumers.isEmpty,
              shouldBeginBatteryHealthMonitoring else {
            return
        }
        beginBatteryHealthMonitoring()
    }

    private func observeBatteryHealth() {
        guard batteryHealthTask == nil else { return }
        let observe = useCases.observeBatteryHealth
        batteryHealthTask = Task { [weak self] in
            let stream = await observe.execute()
            for await value in stream where !Task.isCancelled {
                await self?.receive(value)
            }
        }
    }

    private func receive(_ value: BikeBatteryHealth) {
        batteryHealth = value
        publish()
    }
}
