import BikeDomain
import EnvironmentDomain
import SettingsDomain

extension LiveVehicleSessionService {
    func observeSources() {
        observeTelemetry()
        observeIMU()
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

    private func observeIMU() {
        let useCase = useCases.observeIMU
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

    private func receive(_ value: BikeTelemetry) async {
        telemetry = value
        updatePowerModeRefresh(for: value)
        await updateDeviceSpeedObservation()
        await refreshMotion()
        publish()
    }

    private func receive(_ value: BikeConnection) async {
        let wasReceivingTelemetry = isReceivingTelemetry
        connection = value
        if isReceivingTelemetry {
            updatePowerModeRefresh(for: telemetry)
        } else {
            resetPowerModeRefresh()
        }
        if wasReceivingTelemetry, !isReceivingTelemetry {
            invalidateBatteryHealthMonitoringForConnectionLoss()
        } else if !wasReceivingTelemetry, isReceivingTelemetry {
            resumeBatteryHealthMonitoringIfNeeded()
        }
        await updateIMUMonitoring()
        publish()
    }

    private func receive(_ value: AppSettings) async {
        settings = value
        hasReceivedSettings = true
        await updateDeviceSpeedObservation()
        publish()
    }

    private func receive(_ value: BikeProfileState) async {
        profile = value.profile
        hasReceivedProfile = true
        hasLoadedMotionCalibration = false
        motionCalibration = nil
        motionEstimator.reset()
        await refreshMotion()
        await loadMotionCalibration(for: value.profile)
        publish()
    }

    func updateDeviceSpeedObservation() async {
        guard settings.speedSource.usesDeviceLocation || !locationConsumers.isEmpty else {
            deviceSpeedTask?.cancel()
            deviceSpeedTask = nil
            deviceSpeedExpiryTask?.cancel()
            deviceSpeedExpiryTask = nil
            let hadDeviceSpeedSample = deviceSpeedSample != nil
            deviceSpeedSample = nil
            if hadDeviceSpeedSample {
                await refreshMotion()
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

    private func receive(_ value: DeviceSpeedSample) async {
        deviceSpeedSample = value
        scheduleDeviceSpeedExpiry(for: value)
        await refreshMotion()
        publish()
    }

    private func scheduleDeviceSpeedExpiry(for sample: DeviceSpeedSample) {
        deviceSpeedExpiryTask?.cancel()
        guard let remainingValidity = speedResolver.remainingValidity(of: sample) else {
            deviceSpeedExpiryTask = nil
            return
        }
        let sleep = sleep
        deviceSpeedExpiryTask = Task { [weak self] in
            do {
                try await sleep(.seconds(remainingValidity))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.expireDeviceSpeedSample(sample)
        }
    }

    private func expireDeviceSpeedSample(_ sample: DeviceSpeedSample) async {
        deviceSpeedExpiryTask = nil
        guard deviceSpeedSample == sample else { return }
        deviceSpeedSample = nil
        await refreshMotion()
        publish()
    }

    private func updateIMUMonitoring() async {
        guard isReceivingTelemetry, !isStopping else {
            imuMonitoringGeneration &+= 1
            imuMonitoringStartTask?.cancel()
            if isIMUMonitoring {
                await useCases.stopIMUMonitoring.execute()
                isIMUMonitoring = false
            }
            imuExpiryTask?.cancel()
            imuExpiryTask = nil
            imuSample = nil
            motionEstimator.reset()
            await refreshMotion()
            return
        }
        guard !isIMUMonitoring, imuMonitoringStartTask == nil else { return }
        imuMonitoringGeneration &+= 1
        let generation = imuMonitoringGeneration
        imuMonitoringStartGeneration = generation
        let start = useCases.startIMUMonitoring
        imuMonitoringStartTask = Task { [weak self] in
            let didStart: Bool
            do {
                try await start.execute()
                didStart = true
            } catch {
                didStart = false
            }
            await self?.finishIMUMonitoringStart(
                generation: generation,
                didStart: didStart,
                wasCancelled: Task.isCancelled
            )
        }
    }

    private func receive(_ value: BikeIMUSample) async {
        guard isIMUMonitoring else { return }
        imuSample = value
        scheduleIMUExpiry(for: value)
        await refreshMotion()
        publish()
    }

    private func scheduleIMUExpiry(for sample: BikeIMUSample) {
        imuExpiryTask?.cancel()
        guard let remainingFreshness = motionEstimator.remainingFreshnessDuration(
            for: sample.observedAt
        ) else {
            imuExpiryTask = nil
            return
        }
        let sleep = sleep
        imuExpiryTask = Task { [weak self] in
            do {
                try await sleep(remainingFreshness)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.expireIMUSample(sample)
        }
    }

    private func expireIMUSample(_ sample: BikeIMUSample) async {
        imuExpiryTask = nil
        guard imuSample == sample else { return }
        await refreshMotion()
        publish()
    }

    private func finishIMUMonitoringStart(
        generation: Int,
        didStart: Bool,
        wasCancelled: Bool
    ) async {
        guard imuMonitoringStartGeneration == generation else {
            if didStart {
                await useCases.stopIMUMonitoring.execute()
            }
            return
        }
        imuMonitoringStartTask = nil
        imuMonitoringStartGeneration = nil
        let isCurrent = generation == imuMonitoringGeneration
        if didStart, isCurrent, !wasCancelled, isReceivingTelemetry, !isStopping {
            isIMUMonitoring = true
            return
        }
        if didStart {
            await useCases.stopIMUMonitoring.execute()
        }
        if isCurrent {
            imuSample = nil
            motionEstimator.reset()
            await refreshMotion()
        } else if isReceivingTelemetry, !isStopping {
            await updateIMUMonitoring()
        }
    }

    private func loadMotionCalibration(for profile: BikeProfile?) async {
        motionCalibrationTask?.cancel()
        guard let profile else {
            motionCalibration = nil
            hasLoadedMotionCalibration = true
            motionEstimator.reset()
            await refreshMotion()
            return
        }
        let useCase = useCases.loadMotionCalibration
        motionCalibrationTask = Task { [weak self] in
            let calibration = await useCase.execute(vin: profile.vin)
            guard !Task.isCancelled else { return }
            await self?.receive(calibration, vin: profile.vin)
        }
    }

    private func receive(_ calibration: VehicleMotionCalibration?, vin: String) async {
        motionCalibrationTask = nil
        guard profile?.vin == vin else { return }
        motionCalibration = calibration
        hasLoadedMotionCalibration = true
        motionEstimator.reset()
        await refreshMotion()
        publish()
    }

    func refreshMotion() async {
        let estimation = motionEstimator.estimate(
            imuSample: imuSample,
            calibration: motionCalibration,
            vin: hasLoadedMotionCalibration ? profile?.vin : nil,
            location: deviceSpeedSample,
            bikeSpeedKilometersPerHour: telemetry.speed.kmh
        )
        motion = estimation.snapshot
        guard let calibration = estimation.calibrationToPersist else { return }
        motionCalibration = calibration
        await useCases.saveMotionCalibration.execute(calibration)
    }

    var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = connection.state { true } else { false }
    }
}
