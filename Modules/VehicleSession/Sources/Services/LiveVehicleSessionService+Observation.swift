import BikeDomain
import EnvironmentDomain
import SettingsDomain

extension LiveVehicleSessionService {
    func observeSources() {
        observeTelemetry()
        observeConnection()
        observeSettings()
        observeProfile()
    }

    private func observeTelemetry() {
        let useCase = useCases.observeTelemetry
        observationTasks.append(Task { [weak self] in
            let stream = await useCase.execute()
            for await value in stream where !Task.isCancelled {
                await self?.receive(value)
            }
        })
    }

    private func observeConnection() {
        let useCase = useCases.observeConnection
        observationTasks.append(Task { [weak self] in
            let stream = await useCase.execute()
            for await value in stream where !Task.isCancelled {
                await self?.receive(value)
            }
        })
    }

    private func observeSettings() {
        let useCase = useCases.observeSettings
        observationTasks.append(Task { [weak self] in
            let stream = await useCase.execute()
            for await value in stream where !Task.isCancelled {
                await self?.receive(value)
            }
        })
    }

    private func observeProfile() {
        let useCase = useCases.observeBikeProfile
        observationTasks.append(Task { [weak self] in
            let stream = await useCase.execute()
            for await value in stream where !Task.isCancelled {
                await self?.receive(value)
            }
        })
    }

    private func receive(_ value: BikeTelemetry) {
        telemetry = value
        updateDeviceSpeedObservation()
        publish()
    }

    private func receive(_ value: BikeConnection) {
        connection = value
        publish()
    }

    private func receive(_ value: AppSettings) {
        settings = value
        hasReceivedSettings = true
        updateDeviceSpeedObservation()
        publish()
    }

    private func receive(_ value: BikeProfileState) {
        profile = value.profile
        hasReceivedProfile = true
        publish()
    }

    private func updateDeviceSpeedObservation() {
        guard settings.speedSource.usesDeviceLocation else {
            deviceSpeedTask?.cancel()
            deviceSpeedTask = nil
            deviceSpeedExpiryTask?.cancel()
            deviceSpeedExpiryTask = nil
            deviceSpeedSample = nil
            return
        }
        guard deviceSpeedTask == nil else { return }
        let useCase = useCases.observeDeviceSpeed
        deviceSpeedTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await value in stream where !Task.isCancelled {
                await self?.receive(value)
            }
        }
    }

    private func receive(_ value: DeviceSpeedSample) {
        deviceSpeedSample = value
        scheduleDeviceSpeedExpiry(for: value)
        publish()
    }

    private func scheduleDeviceSpeedExpiry(for sample: DeviceSpeedSample) {
        deviceSpeedExpiryTask?.cancel()
        guard let remainingValidity = speedResolver.remainingValidity(of: sample) else {
            deviceSpeedExpiryTask = nil
            return
        }
        deviceSpeedExpiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(remainingValidity))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.expireDeviceSpeedSample(sample)
        }
    }

    private func expireDeviceSpeedSample(_ sample: DeviceSpeedSample) {
        deviceSpeedExpiryTask = nil
        guard deviceSpeedSample == sample else { return }
        deviceSpeedSample = nil
        publish()
    }
}
