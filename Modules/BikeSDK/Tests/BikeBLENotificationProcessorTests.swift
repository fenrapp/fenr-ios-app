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
            eventEmitter: BikeBLEEventEmitter(eventHub: eventHub),
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
            eventEmitter: BikeBLEEventEmitter(eventHub: eventHub),
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
            eventEmitter: BikeBLEEventEmitter(eventHub: eventHub),
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
