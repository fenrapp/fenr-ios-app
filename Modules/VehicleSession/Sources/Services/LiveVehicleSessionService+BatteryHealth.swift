import BikeDomain

extension LiveVehicleSessionService {
    func beginBatteryHealthMonitoring() {
        guard batteryHealthStartTask == nil, batteryHealthStopTask == nil else { return }
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
            await self?.finishBatteryHealthStart(result)
        }
    }

    func finishBatteryHealthStart(_ result: Result<Void, Error>) async {
        batteryHealthStartTask = nil
        switch result {
        case .success:
            guard !batteryHealthConsumers.isEmpty else {
                scheduleBatteryHealthStop()
                return
            }
            batteryHealthMonitoringState = .active
            observeBatteryHealth()
        case .failure(let error):
            batteryHealthMonitoringState = batteryHealthConsumers.isEmpty
                ? .inactive
                : .failed(String(describing: error))
        }
        publish()
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
        if !batteryHealthConsumers.isEmpty {
            beginBatteryHealthMonitoring()
        }
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
