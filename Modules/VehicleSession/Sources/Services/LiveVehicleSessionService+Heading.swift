import EnvironmentDomain

extension LiveVehicleSessionService {
    func updateDeviceHeadingObservation() async {
        guard !isStopping, !observationTasks.isEmpty, !locationConsumers.isEmpty,
              let useCase = useCases.observeDeviceHeading else {
            await stopDeviceHeadingObservation()
            return
        }
        guard deviceHeadingTask == nil else { return }
        deviceHeadingGeneration &+= 1
        let generation = deviceHeadingGeneration
        deviceHeadingTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await value in stream {
                guard !Task.isCancelled else { return }
                await self?.receiveHeading(value, generation: generation)
            }
        }
    }

    func stopDeviceHeadingObservation() async {
        guard deviceHeadingTask != nil || deviceHeadingExpiryTask != nil || deviceHeadingSample != nil else { return }
        deviceHeadingGeneration &+= 1
        let generation = deviceHeadingGeneration
        let pending = deviceHeadingTask
        let expiry = deviceHeadingExpiryTask
        deviceHeadingTask = nil
        deviceHeadingExpiryTask = nil
        pending?.cancel()
        expiry?.cancel()
        await pending?.value
        await expiry?.value
        guard generation == deviceHeadingGeneration else { return }
        deviceHeadingSample = nil
        await refreshMotion()
    }

    private func receiveHeading(_ value: DeviceHeadingSample, generation: Int) async {
        guard !isStopping, generation == deviceHeadingGeneration else { return }
        deviceHeadingSample = value
        deviceHeadingExpiryTask?.cancel()
        deviceHeadingExpiryTask = nil
        if let remaining = motionEstimator.remainingHeadingValidity(of: value) {
            let sleep = sleep
            deviceHeadingExpiryTask = Task { [weak self] in
                do { try await sleep(.seconds(remaining)) } catch { return }
                guard !Task.isCancelled else { return }
                await self?.expireHeading(value, generation: generation)
            }
        }
        await refreshMotion()
        guard !Task.isCancelled, generation == deviceHeadingGeneration else { return }
        publish()
    }

    private func expireHeading(_ sample: DeviceHeadingSample, generation: Int) async {
        guard generation == deviceHeadingGeneration, deviceHeadingSample == sample else { return }
        deviceHeadingExpiryTask = nil
        deviceHeadingSample = nil
        await refreshMotion()
        guard !Task.isCancelled, generation == deviceHeadingGeneration else { return }
        publish()
    }
}
