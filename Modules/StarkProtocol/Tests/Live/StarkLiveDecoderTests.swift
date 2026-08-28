import Foundation
import StarkProtocol
import Testing

@Suite("Stark live decoders")
struct StarkLiveDecoderTests {
    @Test("Map decodes mode index")
    func mapDecode() throws {
        let payload = try StarkMapDecoder().decode(StarkProtocolFixtures.map)

        #expect(payload.modeIndex == 3)
    }

    @Test("Speed decodes signed speed and RPM")
    func speedDecode() throws {
        let payload = try StarkSpeedDecoder().decode(StarkProtocolFixtures.speedPositive)

        #expect(payload.speedKmhX10 == 421)
        #expect(payload.speedKmh == 42.1)
        #expect(payload.motorRPM == 3_180)
    }

    @Test("Speed decoder handles zero and negative speed")
    func speedEdges() throws {
        let decoder = StarkSpeedDecoder()
        let zero = try decoder.decode(StarkProtocolFixtures.speedZero)
        let negative = try decoder.decode(StarkProtocolFixtures.speedNegative)

        #expect(zero.speedKmhX10 == 0)
        #expect(zero.motorRPM == 0)
        #expect(negative.speedKmhX10 == -1)
        #expect(negative.speedKmh == -0.1)
    }

    @Test("Throttle decoder preserves observed feedback values")
    func throttleDecode() throws {
        let payload = try StarkThrottleDecoder().decode(StarkProtocolFixtures.observedThrottle)

        #expect(payload.idFeedbackRaw == 29)
        #expect(payload.iqFeedbackRaw == -53)
        #expect(payload.positionRaw == 0)
    }

    @Test("IMU decoder preserves observed signed axes")
    func imuDecode() throws {
        let payload = try StarkIMUDecoder().decode(StarkProtocolFixtures.observedIMU)

        #expect(payload.accelerationXRaw == 3)
        #expect(payload.accelerationYRaw == -1_135)
        #expect(payload.accelerationZRaw == 1_178)
        #expect(payload.gyroscopeXRaw == 15)
        #expect(payload.gyroscopeYRaw == -451)
        #expect(payload.gyroscopeZRaw == 927)
    }

    @Test("Live totals decoder preserves unsigned counters")
    func liveTotalsDecode() throws {
        let payload = try StarkLiveTotalsDecoder().decode(StarkProtocolFixtures.observedLiveTotals)

        #expect(payload.firstRawCounter == 17_977)
        #expect(payload.secondRawCounter == 20_519)
        #expect(payload.thirdRawCounter == 0)
        #expect(payload.fourthRawCounter == 202_493)
        #expect(payload.odometerCentiKilometers == 17_977)
        #expect(payload.odometerKilometers == 179.77)
    }

    @Test("Short live payloads report decoder-specific lengths")
    func invalidPayloads() {
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkMapPayloadLayout.requiredLength,
            actual: 0
        )) {
            try StarkMapDecoder().decode(Data())
        }
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkSpeedPayloadLayout.requiredLength,
            actual: StarkProtocolFixtures.invalidTwoBytes.count
        )) {
            try StarkSpeedDecoder().decode(StarkProtocolFixtures.invalidTwoBytes)
        }
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkThrottlePayloadLayout.requiredLength,
            actual: StarkProtocolFixtures.invalidTwoBytes.count
        )) {
            try StarkThrottleDecoder().decode(StarkProtocolFixtures.invalidTwoBytes)
        }
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkIMUPayloadLayout.requiredLength,
            actual: StarkProtocolFixtures.invalidTwoBytes.count
        )) {
            try StarkIMUDecoder().decode(StarkProtocolFixtures.invalidTwoBytes)
        }
        #expect(throws: StarkProtocolError.payloadTooShort(
            expected: StarkLiveTotalsPayloadLayout.requiredLength,
            actual: StarkProtocolFixtures.invalidTwoBytes.count
        )) {
            try StarkLiveTotalsDecoder().decode(StarkProtocolFixtures.invalidTwoBytes)
        }
    }
}
