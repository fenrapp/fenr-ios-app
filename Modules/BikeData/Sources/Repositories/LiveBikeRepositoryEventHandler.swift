import BikeDomain
import BikeSDK
import Foundation

public struct LiveBikeRepositoryEventHandler: Sendable {
    private let telemetryMapper: BikeSDKTelemetryPayloadToDomainMapper
    private let eventMapper: BikeSDKEventToDomainMapper
    private let imuMapper: BikeSDKIMUSampleToDomainMapper
    private let imuRateLimiter: BikeIMUSampleRateLimiter
    private let batteryHealthMapper: BikeSDKTelemetryPayloadToBatteryHealthMapper
    private let batteryDatasetMapper: BikeSDKBatteryDatasetToDomainMapper
    private let connectionSessionPolicy: BikeConnectionSessionPolicy
    private let alphaEvidencePersistence: BikeAlphaEvidencePersistence
    private let now: @Sendable () -> Date

    init(
        telemetryMapper: BikeSDKTelemetryPayloadToDomainMapper,
        eventMapper: BikeSDKEventToDomainMapper,
        imuMapper: BikeSDKIMUSampleToDomainMapper,
        imuRateLimiter: BikeIMUSampleRateLimiter,
        batteryHealthMapper: BikeSDKTelemetryPayloadToBatteryHealthMapper,
        batteryDatasetMapper: BikeSDKBatteryDatasetToDomainMapper,
        connectionSessionPolicy: BikeConnectionSessionPolicy,
        alphaEvidencePersistence: BikeAlphaEvidencePersistence,
        now: @escaping @Sendable () -> Date
    ) {
        self.telemetryMapper = telemetryMapper
        self.eventMapper = eventMapper
        self.imuMapper = imuMapper
        self.imuRateLimiter = imuRateLimiter
        self.batteryHealthMapper = batteryHealthMapper
        self.batteryDatasetMapper = batteryDatasetMapper
        self.connectionSessionPolicy = connectionSessionPolicy
        self.alphaEvidencePersistence = alphaEvidencePersistence
        self.now = now
    }

    func resetSession() async {
        await imuRateLimiter.reset()
    }

    func handle(
        _ event: BikeSDKEvent,
        targets: LiveBikeRepositoryEventTargets
    ) async {
        switch event {
        case .discoveredBike(let bike):
            await targets.discoveredBikesHub.send([.init(vin: bike.vin, rssi: bike.rssi)])
        case .connection(let status):
            await handleConnection(status, targets: targets)
        case .telemetry(let payload):
            await handleTelemetry(payload, targets: targets)
        case .imu(let sample):
            if await imuRateLimiter.shouldAccept(sample.observedAt) {
                await targets.imuHub.send(imuMapper.map(sample))
            }
        case .batteryDatasetCapture(let capture):
            let mappedCapture = BatteryDatasetCapture(
                dataset: batteryDatasetMapper.map(capture.dataset),
                byteCount: capture.byteCount,
                hex: capture.hex,
                date: capture.date
            )
            await targets.batteryHealthStore.storeCapture(mappedCapture)
            await targets.batteryCaptureHub.send(mappedCapture)
        case .rssi(let rssi):
            if let connection = await targets.stateStore.updateConnectionIfChanged({ $0.rssi = rssi }) {
                await targets.connectionHub.send(connection)
            }
            await targets.debugHub.send(eventMapper.rssiDebug(rssi))
        case .peripheral(let name, let identifier):
            let connection = await targets.stateStore.updateConnectionIfChanged {
                $0.peripheralName = name
                $0.peripheralIdentifier = identifier
            }
            if let connection {
                await targets.connectionHub.send(connection)
            }
            await targets.debugHub.send(eventMapper.peripheralDebug(name: name, identifier: identifier))
        case .notification(let notification):
            await targets.debugHub.send(eventMapper.notificationDebug(notification))
        case .debug(let event):
            await targets.debugHub.send(eventMapper.sdkDebug(event))
        case .error(let error):
            await targets.debugHub.send(eventMapper.errorDebug(error))
        }
    }

    private func handleConnection(
        _ status: BikeSDKConnectionStatus,
        targets: LiveBikeRepositoryEventTargets
    ) async {
        let connectionState = eventMapper.connectionState(from: status)
        if connectionSessionPolicy.shouldResetSession(for: connectionState) {
            await resetSession()
            let state = await targets.stateStore.resetSession(connectionState: connectionState)
            await targets.telemetryHub.send(state.telemetry)
            await targets.connectionHub.send(state.connection)
            await targets.batteryHealthStore.reset()
            await targets.batteryHealthHub.send(BikeBatteryHealth())
        } else {
            let connection = await targets.stateStore.updateConnectionIfChanged {
                $0.state = connectionState
            }
            if let connection {
                await targets.connectionHub.send(connection)
            }
        }
        await targets.debugHub.send(eventMapper.connectionDebug(from: status))
    }

    private func handleTelemetry(
        _ payload: BikeSDKTelemetryPayload,
        targets: LiveBikeRepositoryEventTargets
    ) async {
        let date = now()
        let persistedEvidence: Set<BikeAlphaEvidence>
        if case .vin(let vin) = payload {
            persistedEvidence = await alphaEvidencePersistence.persistedEvidence(matching: vin)
        } else {
            persistedEvidence = []
        }
        let telemetry = await targets.stateStore.updateTelemetryIf {
            let didApply = telemetryMapper.apply(payload, to: &$0, date: date)
            if !persistedEvidence.isEmpty {
                $0.detectedPowerTier = .alpha(
                    evidence: $0.detectedPowerTier.alphaEvidence.union(persistedEvidence)
                )
            }
            return didApply || !persistedEvidence.isEmpty
        }
        if let telemetry {
            await targets.telemetryHub.send(telemetry)
            await alphaEvidencePersistence.persistNewEvidence(
                from: telemetry,
                observedAt: date
            )
        }
        await updateBatteryHealth(payload, targets: targets, date: date)
    }

    private func updateBatteryHealth(
        _ payload: BikeSDKTelemetryPayload,
        targets: LiveBikeRepositoryEventTargets,
        date: Date
    ) async {
        let health = await targets.batteryHealthStore.updateHealthIf {
            batteryHealthMapper.apply(payload, to: &$0, date: date)
        }
        if let health {
            await targets.batteryHealthHub.send(health)
        }
    }

}
