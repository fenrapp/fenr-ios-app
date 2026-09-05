import BLETraceDomain
import CoreBluetooth
import Foundation

@MainActor
public struct BikeBLENotificationProcessor {
    private let eventEmitter: BikeBLEEventEmitter
    private let notificationMapper: StarkNotificationToSDKEventMapper
    private let debugSampler: BikeNotificationDebugSampler
    private let traceEmitter: BikeBLETraceEmitter

    init(
        eventEmitter: BikeBLEEventEmitter,
        notificationMapper: StarkNotificationToSDKEventMapper,
        debugSampler: BikeNotificationDebugSampler,
        traceEmitter: BikeBLETraceEmitter
    ) {
        self.eventEmitter = eventEmitter
        self.notificationMapper = notificationMapper
        self.debugSampler = debugSampler
        self.traceEmitter = traceEmitter
    }

    public func process(characteristic: UUID, data: Data, date: Date) async -> Bool {
        let payload: BikeSDKTelemetryPayload?
        let decodeStatus: BLETraceDecodeStatus
        let decodeDetail: String?
        do {
            payload = try notificationMapper.telemetryPayload(
                characteristic: characteristic,
                data: data
            )
            if let payload {
                if case .imu(let imuPayload) = payload {
                    await eventEmitter.send(.imu(.init(payload: imuPayload, observedAt: date)))
                } else {
                    await eventEmitter.send(.telemetry(payload))
                }
                decodeStatus = .decoded
                decodeDetail = traceEmitter.isRecording ? notificationMapper.debug(
                    characteristic: characteristic,
                    data: data,
                    payload: payload,
                    date: date
                ).decodedDetail : nil
            } else {
                decodeStatus = .unmapped
                decodeDetail = nil
            }
        } catch {
            payload = nil
            decodeStatus = .failed
            decodeDetail = String(describing: error)
            await eventEmitter.send(.error(.decodeFailed(
                characteristic: characteristic,
                message: String(describing: error)
            )))
        }
        await traceEmitter.record(
            category: "decoder",
            operation: .decodeResult,
            direction: .internalEvent,
            characteristicUUID: CBUUID(nsuuid: characteristic),
            decodeStatus: decodeStatus,
            detail: decodeDetail
        )
        if traceEmitter.isRecording, debugSampler.shouldEmit(characteristic: characteristic, date: date) {
            let debug = notificationMapper.debug(
                characteristic: characteristic,
                data: data,
                payload: payload,
                date: date
            )
            await eventEmitter.sendDiagnostic(.notification(debug))
        }
        return payload != nil
    }

    public func resetDebugSampling() {
        debugSampler.reset()
    }

}
