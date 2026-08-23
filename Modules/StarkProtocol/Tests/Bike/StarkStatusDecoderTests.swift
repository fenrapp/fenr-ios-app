import StarkProtocol
import Testing

@Suite("Stark bike status decoder")
struct StarkStatusDecoderTests {
    private let decoder = StarkStatusDecoder()

    @Test("Status decodes flags and crawl mode")
    func statusDecode() throws {
        let payload = try decoder.decode(StarkProtocolFixtures.statusAllActive)

        #expect(payload.isOn)
        #expect(payload.isCharging)
        #expect(payload.isChargerConnected)
        #expect(payload.isInGear)
        #expect(payload.isFaultActive)
        #expect(payload.isCrawlActive)
        #expect(payload.isCrawlForward)
        #expect(payload.isRightBlinkerOn)
        #expect(payload.isCheckEngineLightOn)
        #expect(payload.lockStatus == 1)
        #expect(payload.lockTime == 42)
        #expect(payload.updateAvailable)
        #expect(payload.batteryStatus == 0x12345678)
    }

    @Test("Status decoder handles reverse crawl")
    func crawlReverse() throws {
        let payload = try decoder.decode(StarkProtocolFixtures.statusCrawlReverse)

        #expect(payload.isCrawlActive)
        #expect(!payload.isCrawlForward)
    }

    @Test("Short status reports required length")
    func invalidPayload() {
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkStatusPayloadLayout.requiredLength,
            actual: StarkProtocolFixtures.invalidTwoBytes.count
        )) {
            try decoder.decode(StarkProtocolFixtures.invalidTwoBytes)
        }
    }
}
