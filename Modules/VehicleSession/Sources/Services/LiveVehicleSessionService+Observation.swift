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
        updatePowerModeRefresh(for: value)
        updateDeviceSpeedObservation()
        publish()
    }

    private func receive(_ value: BikeConnection) {
        connection = value
        if !isReceivingTelemetry {
            resetPowerModeRefresh()
        }
        updateDeviceMotionObservation()
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
        loadMotionCalibration(for: value.profile)
        publish()
    }

    func updateDeviceSpeedObservation() {
        guard settings.speedSource.usesDeviceLocation || !locationConsumers.isEmpty else {
            deviceSpeedTask?.cancel()
            deviceSpeedTask = nil
            deviceSpeedExpiryTask?.cancel()
            deviceSpeedExpiryTask = nil
            let hadDeviceSpeedSample = deviceSpeedSample != nil
            deviceSpeedSample = nil
            if hadDeviceSpeedSample {
                refreshMotion()
            }
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
        refreshMotion()
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
        refreshMotion()
        publish()
    }

    private func updateDeviceMotionObservation() {
        guard isReceivingTelemetry else {
            deviceMotionTask?.cancel()
            deviceMotionTask = nil
            deviceMotionExpiryTask?.cancel()
            deviceMotionExpiryTask = nil
            deviceMotionSample = nil
            motionEstimator.reset()
            refreshMotion()
            return
        }
        guard deviceMotionTask == nil else { return }
        let useCase = useCases.observeDeviceMotion
        deviceMotionTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await value in stream where !Task.isCancelled {
                await self?.receive(value)
            }
        }
    }

    private func receive(_ value: DeviceMotionSample) {
        deviceMotionSample = value
        scheduleDeviceMotionExpiry(for: value)
        refreshMotion()
        publish()
    }

    private func scheduleDeviceMotionExpiry(for sample: DeviceMotionSample) {
        deviceMotionExpiryTask?.cancel()
        deviceMotionExpiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.expireDeviceMotionSample(sample)
        }
    }

    private func expireDeviceMotionSample(_ sample: DeviceMotionSample) {
        deviceMotionExpiryTask = nil
        guard deviceMotionSample == sample else { return }
        refreshMotion()
        publish()
    }

    private func loadMotionCalibration(for profile: BikeProfile?) {
        motionCalibrationTask?.cancel()
        guard let profile else {
            motionCalibration = nil
            motionEstimator.reset()
            refreshMotion()
            return
        }
        let useCase = useCases.loadMotionCalibration
        motionCalibrationTask = Task { [weak self] in
            let calibration = await useCase.execute(vin: profile.vin)
            guard !Task.isCancelled else { return }
            await self?.receive(calibration, vin: profile.vin)
        }
    }

    private func receive(_ calibration: VehicleMotionCalibration?, vin: String) {
        motionCalibrationTask = nil
        guard profile?.vin == vin else { return }
        motionCalibration = calibration
        motionEstimator.reset()
        refreshMotion()
        publish()
    }

    func refreshMotion() {
        motion = motionEstimator.estimate(
            deviceMotion: deviceMotionSample,
            calibration: motionCalibration,
            location: deviceSpeedSample
        )
    }

    private var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = connection.state { true } else { false }
    }
}
