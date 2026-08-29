@testable import BikeSDK
import Foundation
import StarkProtocol
import Testing

@MainActor
@Suite("BLE notification processing")
struct BikeBLENotificationProcessorTests {
    @Test("Telemetry is emitted before sampled debug data")
    func prioritizesTelemetry() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        let processor = BikeBLENotificationProcessor(
            eventEmitter: makeEventEmitter(eventHub: eventHub),
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 1),
            traceEmitter: makeTraceEmitter()
        )

        let result = await processor.process(
            characteristic: StarkUUIDs.batterySOC,
            data: BikeSDKPayloadFixtures.battery,
            date: Date(timeIntervalSince1970: 0)
        )
        var iterator = stream.makeAsyncIterator()
        let firstEvent = await iterator.next()
        let secondEvent = await iterator.next()

        #expect(result)
        #expect(firstEvent == .telemetry(.battery(.init(
            stateOfChargePercent: 91,
            stateOfHealthPercent: 99,
            dcBusRaw: nil
        ))))
        guard case .notification = secondEvent else {
            Issue.record("Expected sampled notification debug after telemetry")
            return
        }
    }

    @Test("Debug packets inside the sampling interval do not enter the event stream")
    func limitsDebugPacketRate() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        let initialDate = Date(timeIntervalSince1970: 0)
        let processor = BikeBLENotificationProcessor(
            eventEmitter: makeEventEmitter(eventHub: eventHub),
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 1),
            traceEmitter: makeTraceEmitter()
        )

        _ = await processor.process(
            characteristic: StarkUUIDs.batterySOC,
            data: BikeSDKPayloadFixtures.battery,
            date: initialDate
        )
        _ = await processor.process(
            characteristic: StarkUUIDs.batterySOC,
            data: BikeSDKPayloadFixtures.battery,
            date: initialDate.addingTimeInterval(0.5)
        )
        var iterator = stream.makeAsyncIterator()
        let firstEvent = await iterator.next()
        let secondEvent = await iterator.next()
        let thirdEvent = await iterator.next()
        let events = [firstEvent, secondEvent, thirdEvent].compactMap { $0 }

        #expect(events.count == 3)
        #expect(events.filter(\.isNotification).count == 1)
        #expect(events.filter(\.isTelemetry).count == 2)
    }

    @Test("Invalid telemetry emits a decode error and preserves the debug packet")
    func invalidTelemetryEmitsDecodeError() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        let processor = BikeBLENotificationProcessor(
            eventEmitter: makeEventEmitter(eventHub: eventHub),
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 1),
            traceEmitter: makeTraceEmitter()
        )

        let didDecode = await processor.process(
            characteristic: StarkUUIDs.batterySOC,
            data: BikeSDKPayloadFixtures.invalidBattery,
            date: Date(timeIntervalSince1970: 0)
        )
        var iterator = stream.makeAsyncIterator()
        let firstEvent = await iterator.next()
        let secondEvent = await iterator.next()

        #expect(!didDecode)
        guard case let .error(.decodeFailed(characteristic, message)) = firstEvent else {
            Issue.record("Expected a telemetry decode error")
            return
        }
        #expect(characteristic == StarkUUIDs.batterySOC)
        #expect(!message.isEmpty)
        guard case .notification = secondEvent else {
            Issue.record("Expected debug data after the decode error")
            return
        }
    }

    @Test("IMU preserves signed axes and the Core Bluetooth callback timestamp")
    func emitsTimestampedIMU() async {
        let eventHub = AsyncEventHub<BikeSDKEvent>(bufferingPolicy: .unbounded)
        let stream = await eventHub.stream()
        let date = Date(timeIntervalSince1970: 123)
        let processor = BikeBLENotificationProcessor(
            eventEmitter: makeEventEmitter(eventHub: eventHub),
            notificationMapper: makeNotificationMapper(),
            debugSampler: BikeNotificationDebugSampler(minimumInterval: 1),
            traceEmitter: makeTraceEmitter()
        )

        let didDecode = await processor.process(
            characteristic: StarkUUIDs.liveIMU,
            data: BikeSDKPayloadFixtures.imu,
            date: date
        )
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        #expect(didDecode)
        guard case let .imu(sample) = event else {
            Issue.record("Expected a dedicated IMU event")
            return
        }
        #expect(sample.observedAt == date)
        #expect(sample.payload.accelerationXRaw == 3)
        #expect(sample.payload.accelerationYRaw == -1_135)
        #expect(sample.payload.accelerationZRaw == 1_178)
        #expect(sample.payload.gyroscopeXRaw == 15)
        #expect(sample.payload.gyroscopeYRaw == -451)
        #expect(sample.payload.gyroscopeZRaw == 927)
    }
}

private extension BikeSDKEvent {
    var isNotification: Bool {
        if case .notification = self { return true }
        return false
    }

    var isTelemetry: Bool {
        if case .telemetry = self { return true }
        return false
    }
}
