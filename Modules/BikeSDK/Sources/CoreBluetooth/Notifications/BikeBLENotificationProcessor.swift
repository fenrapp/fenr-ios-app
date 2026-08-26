import Foundation

@MainActor
public struct BikeBLENotificationProcessor {
    private let eventEmitter: BikeBLEEventEmitter
    private let notificationMapper: StarkNotificationToSDKEventMapper
    private let debugSampler: BikeNotificationDebugSampler

    public init(
        eventEmitter: BikeBLEEventEmitter,
        notificationMapper: StarkNotificationToSDKEventMapper,
        debugSampler: BikeNotificationDebugSampler
    ) {
        self.eventEmitter = eventEmitter
        self.notificationMapper = notificationMapper
        self.debugSampler = debugSampler
    }

    public func process(characteristic: UUID, data: Data, date: Date) async -> Bool {
        let payload = await sendTelemetry(characteristic: characteristic, data: data)
        if debugSampler.shouldEmit(characteristic: characteristic, date: date) {
            let debug = notificationMapper.debug(
                characteristic: characteristic,
                data: data,
                payload: payload,
                date: date
            )
            await eventEmitter.send(.notification(debug))
        }
        return payload != nil
    }

    public func resetDebugSampling() {
        debugSampler.reset()
    }

    private func sendTelemetry(characteristic: UUID, data: Data) async -> BikeSDKTelemetryPayload? {
        do {
            guard let payload = try notificationMapper.telemetryPayload(
                characteristic: characteristic,
                data: data
            ) else {
                return nil
            }
            await eventEmitter.send(.telemetry(payload))
            return payload
        } catch {
            await eventEmitter.send(.error(.decodeFailed(
                characteristic: characteristic,
                message: String(describing: error)
            )))
            return nil
        }
    }
}
