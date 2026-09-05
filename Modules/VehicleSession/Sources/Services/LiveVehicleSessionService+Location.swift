import EnvironmentDomain

extension LiveVehicleSessionService {
    func updateDeviceSpeedObservation() async {
        await updateDeviceHeadingObservation()
        guard !isStopping, !observationTasks.isEmpty else { return }
        guard settings.speedSource.usesDeviceLocation || !locationConsumers.isEmpty else {
            await stopDeviceLocationObservation()
            return
        }
        guard deviceSpeedTask == nil else { return }
        deviceLocationGeneration &+= 1
        let generation = deviceLocationGeneration
        let useCase = useCases.observeDeviceSpeed
        deviceSpeedTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await value in stream {
                guard !Task.isCancelled else { return }
                await self?.receiveLocation(value, generation: generation)
            }
        }
    }

    func stopDeviceLocationObservation() async {
        guard deviceSpeedTask != nil || deviceSpeedSample != nil || devicePositionSample != nil else { return }
        deviceLocationGeneration &+= 1
        let generation = deviceLocationGeneration
        let tasks = [deviceSpeedTask, deviceSpeedExpiryTask, devicePositionExpiryTask].compactMap { $0 }
        deviceSpeedTask = nil
        deviceSpeedExpiryTask = nil
        devicePositionExpiryTask = nil
        deviceSpeedSample = nil
        devicePositionSample = nil
        tasks.forEach { $0.cancel() }
        for task in tasks { await task.value }
        guard generation == deviceLocationGeneration else { return }
        await refreshMotion()
    }

    private func receiveLocation(_ value: DeviceSpeedSample, generation: Int) async {
        guard !isStopping, generation == deviceLocationGeneration else { return }
        deviceSpeedSample = value
        scheduleDeviceSpeedExpiry(for: value, generation: generation)
        if let remaining = motionEstimator.remainingPositionValidity(of: value),
           devicePositionSample.map({ value.observedAt >= $0.observedAt }) ?? true {
            devicePositionSample = value
            scheduleDevicePositionExpiry(for: value, remaining: remaining, generation: generation)
        }
        await refreshMotion()
        guard !Task.isCancelled, generation == deviceLocationGeneration else { return }
        publish()
    }

    private func scheduleDeviceSpeedExpiry(for sample: DeviceSpeedSample, generation: Int) {
        deviceSpeedExpiryTask?.cancel()
        deviceSpeedExpiryTask = nil
        guard let remaining = speedResolver.remainingValidity(of: sample) else { return }
        let sleep = sleep
        deviceSpeedExpiryTask = Task { [weak self] in
            do { try await sleep(.seconds(remaining)) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.expireDeviceSpeedSample(sample, generation: generation)
        }
    }

    private func scheduleDevicePositionExpiry(
        for sample: DeviceSpeedSample, remaining: Double, generation: Int
    ) {
        devicePositionExpiryTask?.cancel()
        let sleep = sleep
        devicePositionExpiryTask = Task { [weak self] in
            do { try await sleep(.seconds(remaining)) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.expireDevicePositionSample(sample, generation: generation)
        }
    }

    private func expireDeviceSpeedSample(_ sample: DeviceSpeedSample, generation: Int) async {
        guard generation == deviceLocationGeneration, deviceSpeedSample == sample else { return }
        deviceSpeedExpiryTask = nil
        deviceSpeedSample = nil
        await refreshMotion()
        guard !Task.isCancelled, generation == deviceLocationGeneration else { return }
        publish()
    }

    private func expireDevicePositionSample(_ sample: DeviceSpeedSample, generation: Int) async {
        guard generation == deviceLocationGeneration, devicePositionSample == sample else { return }
        devicePositionExpiryTask = nil
        devicePositionSample = nil
        await refreshMotion()
        guard !Task.isCancelled, generation == deviceLocationGeneration else { return }
        publish()
    }
}
