@testable import BikeSDK
import Foundation
import Testing

@MainActor
@Suite("BLE notification debug sampling")
struct BikeNotificationDebugSamplerTests {
    @Test("First packet is emitted and packets inside the interval are skipped")
    func samplesPacketsByCharacteristic() {
        let sampler = BikeNotificationDebugSampler(minimumInterval: 1)
        let characteristic = UUID()
        let initialDate = Date(timeIntervalSince1970: 0)

        let firstResult = sampler.shouldEmit(characteristic: characteristic, date: initialDate)
        let earlyResult = sampler.shouldEmit(
            characteristic: characteristic,
            date: initialDate.addingTimeInterval(0.5)
        )
        let intervalResult = sampler.shouldEmit(
            characteristic: characteristic,
            date: initialDate.addingTimeInterval(1)
        )

        #expect(firstResult)
        #expect(!earlyResult)
        #expect(intervalResult)
    }

    @Test("Characteristics have independent sampling windows")
    func samplesCharacteristicsIndependently() {
        let sampler = BikeNotificationDebugSampler(minimumInterval: 1)
        let date = Date(timeIntervalSince1970: 0)

        let firstResult = sampler.shouldEmit(characteristic: UUID(), date: date)
        let secondResult = sampler.shouldEmit(characteristic: UUID(), date: date)

        #expect(firstResult)
        #expect(secondResult)
    }

    @Test("Reset allows the next packet immediately")
    func resetClearsSamplingState() {
        let sampler = BikeNotificationDebugSampler(minimumInterval: 1)
        let characteristic = UUID()
        let date = Date(timeIntervalSince1970: 0)
        _ = sampler.shouldEmit(characteristic: characteristic, date: date)

        sampler.reset()
        let result = sampler.shouldEmit(characteristic: characteristic, date: date)

        #expect(result)
    }
}
