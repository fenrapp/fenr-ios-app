import AsyncSupport
@testable import BikeData
import BikeDomain
import BikeSDK
import Foundation

func makeRepository(
    client: BikeTelemetryClient,
    profileRepository: (any BikeProfileRepository)? = nil,
    imuMinimumInterval: TimeInterval = .zero,
    now: @escaping @Sendable () -> Date = Date.init,
    diagnosticsEnabled: @escaping @Sendable () -> Bool = { true }
) -> LiveBikeRepository {
    let stateStore = BikeRepositoryStateStore()
    let telemetryHub = AsyncEventHub<BikeTelemetry>(bufferingPolicy: .unbounded)
    return LiveBikeRepository(
        client: client,
        eventHandler: makeEventHandler(
            profileRepository: profileRepository,
            imuMinimumInterval: imuMinimumInterval,
            now: now,
            diagnosticsEnabled: diagnosticsEnabled
        ),
        stateStore: stateStore, telemetryHub: telemetryHub,
        connectionHub: .init(bufferingPolicy: .unbounded),
        debugHub: .init(bufferingPolicy: .unbounded),
        imuHub: .init(bufferingPolicy: .unbounded),
        batteryHealthStore: .init(),
        batteryHealthHub: .init(bufferingPolicy: .unbounded),
        batteryCaptureHub: .init(bufferingPolicy: .unbounded),
        discoveredBikesHub: .init(bufferingPolicy: .unbounded),
        controlService: .init(
            client: client,
            chargePowerMapper: .init(),
            bikeLockMapper: .init(),
            advancedPowerModeMapper: .init(), tractionMapper: .init()
        ),
        curveConfirmation: .init(stateStore: stateStore, telemetryHub: telemetryHub)
    )
}

private func makeEventHandler(
    profileRepository: (any BikeProfileRepository)?,
    imuMinimumInterval: TimeInterval,
    now: @escaping @Sendable () -> Date,
    diagnosticsEnabled: @escaping @Sendable () -> Bool
) -> LiveBikeRepositoryEventHandler {
    LiveBikeRepositoryEventHandler(
        telemetryMapper: .init(powerCalculator: .init(), maximumPowerInputSkew: 2),
        eventMapper: .init(
            connectionMapper: .init(),
            connectionDebugMapper: .init(),
            notificationDebugMapper: .init()
        ),
        imuMapper: .init(),
        imuRateLimiter: .init(minimumInterval: imuMinimumInterval),
        batteryHealthMapper: .init(),
        batteryDatasetMapper: .init(),
        connectionSessionPolicy: .init(),
        alphaEvidencePersistence: .init(profileRepository: profileRepository),
        now: now,
        diagnosticsEnabled: diagnosticsEnabled
    )
}
