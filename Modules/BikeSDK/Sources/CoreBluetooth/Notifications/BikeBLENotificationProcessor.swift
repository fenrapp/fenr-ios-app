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
        let didDecodeTelemetry = await sendTelemetry(characteristic: characteristic, data: data)
        if debugSampler.shouldEmit(characteristic: characteristic, date: date) {
            let debug = notificationMapper.debug(characteristic: characteristic, data: data, date: date)
            await eventEmitter.send(.notification(debug))
        }
        return didDecodeTelemetry
    }

    public func resetDebugSampling() {
        debugSampler.reset()
    }

    private func sendTelemetry(characteristic: UUID, data: Data) async -> Bool {
        do {
            guard let payload = try notificationMapper.telemetryPayload(
                characteristic: characteristic,
                data: data
            ) else {
                return false
            }
            await eventEmitter.send(.telemetry(payload))
            return true
        } catch {
            await eventEmitter.send(.error(.decodeFailed(
                characteristic: characteristic,
                message: String(describing: error)
            )))
            return false
        }
    }
}
