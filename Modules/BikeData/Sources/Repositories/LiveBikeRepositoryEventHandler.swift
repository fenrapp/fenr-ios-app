import BikeDomain
import BikeSDK
import Foundation

public struct LiveBikeRepositoryEventHandler: Sendable {
    private let telemetryMapper: BikeSDKTelemetryPayloadToDomainMapper
    private let eventMapper: BikeSDKEventToDomainMapper
    private let batteryHealthMapper: BikeSDKTelemetryPayloadToBatteryHealthMapper
    private let batteryDatasetMapper: BikeSDKBatteryDatasetToDomainMapper
    private let connectionSessionPolicy: BikeConnectionSessionPolicy
    private let profileRepository: (any BikeProfileRepository)?

    public init(
        telemetryMapper: BikeSDKTelemetryPayloadToDomainMapper,
        eventMapper: BikeSDKEventToDomainMapper,
        batteryHealthMapper: BikeSDKTelemetryPayloadToBatteryHealthMapper,
        batteryDatasetMapper: BikeSDKBatteryDatasetToDomainMapper,
        connectionSessionPolicy: BikeConnectionSessionPolicy,
        profileRepository: (any BikeProfileRepository)? = nil
    ) {
        self.telemetryMapper = telemetryMapper
        self.eventMapper = eventMapper
        self.batteryHealthMapper = batteryHealthMapper
        self.batteryDatasetMapper = batteryDatasetMapper
        self.connectionSessionPolicy = connectionSessionPolicy
        self.profileRepository = profileRepository
    }

    func handle(
        _ event: BikeSDKEvent,
        targets: LiveBikeRepositoryEventTargets
    ) async {
        switch event {
        case .discoveredBike(let bike):
            await targets.discoveredBikesHub.send([.init(vin: bike.vin, rssi: bike.rssi)])
        case .connection(let status):
            let connectionState = eventMapper.connectionState(from: status)
            if connectionSessionPolicy.shouldResetSession(for: connectionState) {
                let state = await targets.stateStore.resetSession(connectionState: connectionState)
                await targets.telemetryHub.send(state.telemetry)
                await targets.connectionHub.send(state.connection)
                await targets.batteryHealthStore.reset()
                await targets.batteryHealthHub.send(BikeBatteryHealth())
            } else {
                let connection = await targets.stateStore.updateConnection {
                    $0.state = connectionState
                }
                await targets.connectionHub.send(connection)
            }
            await targets.debugHub.send(eventMapper.connectionDebug(from: status))
        case .telemetry(let payload):
            let persistedEvidence = await persistedAlphaEvidence(for: payload)
            let telemetry = await targets.stateStore.updateTelemetry {
                telemetryMapper.apply(payload, to: &$0, date: Date())
                if !persistedEvidence.isEmpty {
                    $0.detectedPowerTier = .alpha(
                        evidence: $0.detectedPowerTier.alphaEvidence.union(persistedEvidence)
                    )
                }
            }
            await targets.telemetryHub.send(telemetry)
            await persistAlphaEvidenceIfNeeded(from: telemetry)
            await updateBatteryHealth(payload, targets: targets)
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
            let connection = await targets.stateStore.updateConnection { $0.rssi = rssi }
            await targets.connectionHub.send(connection)
            await targets.debugHub.send(eventMapper.rssiDebug(rssi))
        case .peripheral(let name, let identifier):
            let connection = await targets.stateStore.updateConnection {
                $0.peripheralName = name
                $0.peripheralIdentifier = identifier
            }
            await targets.connectionHub.send(connection)
            await targets.debugHub.send(eventMapper.peripheralDebug(name: name, identifier: identifier))
        case .notification(let notification):
            await targets.debugHub.send(eventMapper.notificationDebug(notification))
        case .debug(let event):
            await targets.debugHub.send(eventMapper.sdkDebug(event))
        case .error(let error):
            await targets.debugHub.send(eventMapper.errorDebug(error))
        }
    }

    private func persistAlphaEvidenceIfNeeded(from telemetry: BikeTelemetry) async {
        guard let profileRepository,
              case .alpha(let evidence) = telemetry.detectedPowerTier,
              !evidence.isEmpty,
              var profile = await profileRepository.loadProfile(),
              telemetry.vin.isEmpty || telemetry.vin == profile.vin
        else { return }
        let mergedEvidence = profile.alphaEvidence.union(evidence)
        guard mergedEvidence != profile.alphaEvidence else { return }
        profile.alphaEvidence = mergedEvidence
        profile.alphaDetectedAt = Date()
        await profileRepository.saveProfile(profile)
    }

    private func updateBatteryHealth(
        _ payload: BikeSDKTelemetryPayload,
        targets: LiveBikeRepositoryEventTargets
    ) async {
        let health = await targets.batteryHealthStore.updateHealth {
            batteryHealthMapper.apply(payload, to: &$0, date: Date())
        }
        await targets.batteryHealthHub.send(health)
    }

    private func persistedAlphaEvidence(
        for payload: BikeSDKTelemetryPayload
    ) async -> Set<BikeAlphaEvidence> {
        guard case .vin(let vin) = payload,
              let profileRepository,
              let profile = await profileRepository.loadProfile(),
              profile.vin == vin
        else { return [] }
        return profile.alphaEvidence
    }
}
