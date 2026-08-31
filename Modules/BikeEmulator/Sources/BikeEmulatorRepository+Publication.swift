import BikeDomain
import Foundation

extension BikeEmulatorRepository {
    func scheduleUpdates(generation updateGeneration: UInt64) {
        guard updateTask == nil else { return }
        let runtime = runtime
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await runtime.sleep(runtime.telemetryInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.advance(generation: updateGeneration)
            }
        }
    }

    func scheduleIMUUpdates(generation updateGeneration: UInt64) {
        guard imuUpdateTask == nil else { return }
        let runtime = runtime
        imuUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await runtime.sleep(runtime.imuInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.publishIMU(generation: updateGeneration)
            }
        }
    }

    func publishCurrentState(expectedGeneration: UInt64? = nil) async {
        guard canPublish(expectedGeneration: expectedGeneration) else { return }
        let date = await runtime.now()
        guard canPublish(expectedGeneration: expectedGeneration) else { return }
        if isConnected {
            await publishConnectionIfChanged(makeConnection())
        }
        guard canPublish(expectedGeneration: expectedGeneration) else { return }
        await telemetryHub.send(makeTelemetry(date: date))
        guard batteryHealthMonitoringLeaseCount > 0,
              canPublish(expectedGeneration: expectedGeneration)
        else { return }
        await publishBatteryHealth(date: date)
        guard canPublish(expectedGeneration: expectedGeneration) else { return }
        await captureHub.replace(with: makeCaptures(date: date))
    }

    func publishBatteryHealth(date: Date? = nil) async {
        let effectiveDate: Date
        if let date {
            effectiveDate = date
        } else {
            effectiveDate = await runtime.now()
        }
        await batteryHealthHub.send(makeBatteryHealth(date: effectiveDate))
    }

    func currentPowerModeConfigurations() -> [Int: BikePowerModeConfiguration] {
        var configurations = BikeEmulatorPowerModeTelemetryFactory.configurations(
            preset: powerModePreset,
            activeMapNumber: activeMapNumber
        )
        configurations.merge(powerModeOverrides) { _, override in override }
        return configurations
    }

    func publishConnectionIfChanged(_ connection: BikeConnection) async {
        guard connection != lastPublishedConnection else { return }
        lastPublishedConnection = connection
        await connectionHub.send(connection)
    }

    private func advance(generation updateGeneration: UInt64) async {
        guard lifecycleState == .started,
              generation == updateGeneration,
              isConnected
        else { return }
        tick += 1
        await publishCurrentState(expectedGeneration: updateGeneration)
    }

    private func publishIMU(generation updateGeneration: UInt64) async {
        guard lifecycleState == .started,
              generation == updateGeneration,
              isConnected,
              imuMonitoringLeaseCount > 0
        else { return }
        let date = await runtime.now()
        guard lifecycleState == .started,
              generation == updateGeneration,
              isConnected,
              imuMonitoringLeaseCount > 0
        else { return }
        let phase = date.timeIntervalSinceReferenceDate
        let rollRadians = sin(phase * 0.7) * 12 * .pi / 180
        let pitchRadians = sin(phase * 0.37) * 6 * .pi / 180
        let acceleration = BikeIMUVector(
            x: -sin(pitchRadians) * BikeEmulatorConstants.debugOneGRaw,
            y: sin(rollRadians) * cos(pitchRadians) * BikeEmulatorConstants.debugOneGRaw,
            z: cos(rollRadians) * cos(pitchRadians) * BikeEmulatorConstants.debugOneGRaw
        )
        let gyroscope = BikeIMUVector(
            x: cos(phase * 0.7) * 8.4,
            y: cos(phase * 0.37) * 2.22,
            z: .zero
        )
        await imuHub.send(.init(
            accelerationRaw: acceleration,
            gyroscopeRaw: gyroscope,
            observedAt: date
        ))
    }

    private func canPublish(expectedGeneration: UInt64?) -> Bool {
        guard let expectedGeneration else {
            return lifecycleState != .stopping
        }
        return isConnected
            && generation == expectedGeneration
            && (lifecycleState == .starting || lifecycleState == .started)
    }

    private func makeConnection() -> BikeConnection {
        BikeEmulatorPayloadFactory.makeConnection()
    }

    private func makeTelemetry(date: Date) -> BikeTelemetry {
        var telemetry = BikeEmulatorPayloadFactory.makeTelemetry(
            scenario: scenario,
            tick: tick,
            context: .init(
                powerModePreset: powerModePreset,
                activeMapNumber: activeMapNumber,
                chargeTargetPercent: chargeTargetPercent,
                date: date
            ),
            powerCalculator: powerCalculator
        )
        telemetry.powerModeConfigurations.merge(powerModeOverrides) { _, override in override }
        return telemetry
    }

    private func makeBatteryHealth(date: Date) -> BikeBatteryHealth {
        BikeEmulatorBatteryPayloadFactory.makeBatteryHealth(
            scenario: scenario,
            tick: tick,
            date: date,
            chargePowerLimitWatts: chargePowerLimitWatts,
            chargeTargetPercent: chargeTargetPercent
        )
    }

    func makeCaptures(date: Date) -> [BatteryDatasetCapture] {
        BikeEmulatorBatteryPayloadFactory.makeCaptures(
            scenario: scenario,
            tick: tick,
            date: date
        )
    }
}
