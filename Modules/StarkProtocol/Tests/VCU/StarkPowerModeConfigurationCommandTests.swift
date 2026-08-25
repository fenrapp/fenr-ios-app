import Foundation
import StarkProtocol
import Testing

@Suite("Stark VCU power mode configuration")
struct StarkPowerModeConfigurationCommandTests {
    @Test("Encodes map and traction reads for all five maps")
    func encodesReads() throws {
        #expect(try StarkPowerModeConfigurationCommand.readPacket(mapIndex: 0) == Data([0, 0, 0]))
        #expect(try StarkPowerModeConfigurationCommand.readPacket(mapIndex: 4) == Data([0, 0, 4]))
        #expect(try StarkTractionControlConfigurationCommand.readPacket(mapIndex: 3) == Data([0, 8, 3]))
    }

    @Test("Decodes horsepower and signed regeneration")
    func decodesPowerMode() throws {
        let payload = try StarkPowerModeConfigurationCommand.decodeResponse(
            Data([0, 0, 0, 3, 100, 0, 0x9C, 0xFF, 7]),
            expectedMapIndex: 3
        )

        #expect(payload.mapIndex == 3)
        #expect(payload.torqueRaw == 100)
        #expect(payload.horsepower == 80)
        #expect(payload.regenerationRaw == -100)
        #expect(payload.regenerativeBrakingPercent == -100)
        #expect(payload.curve == 7)
    }

    @Test("Decodes the physical VCU notification envelope and ignores trailing bytes")
    func decodesPhysicalPowerModeNotification() throws {
        let payload = try StarkPowerModeConfigurationCommand.decodeResponse(
            Data([2, 0, 0, 4, 100, 0, 70, 0, 0, 0]),
            expectedMapIndex: 4
        )

        #expect(payload.mapIndex == 4)
        #expect(payload.horsepower == 80)
        #expect(payload.regenerativeBrakingPercent == 70)
    }

    @Test("Decodes signed traction values in tenths of a percent")
    func decodesTraction() throws {
        let payload = try StarkTractionControlConfigurationCommand.decodeResponse(
            Data([0, 8, 0, 2, 0x5F, 0x01, 0x38, 0xFF]),
            expectedMapIndex: 2
        )

        #expect(payload.powerRaw == 351)
        #expect(payload.powerPercent == 35.1)
        #expect(payload.brakingRaw == -200)
        #expect(payload.brakingPercent == -20)
    }

    @Test("Decodes physical traction notification with extended VCU data")
    func decodesPhysicalTractionNotification() throws {
        let response = Data([2, 8, 0, 1, 200, 0, 200, 0] + Array(repeating: 0, count: 28))
        let payload = try StarkTractionControlConfigurationCommand.decodeResponse(
            response,
            expectedMapIndex: 1
        )

        #expect(payload.mapIndex == 1)
        #expect(payload.powerPercent == 20)
        #expect(payload.brakingPercent == 20)
    }

    @Test("Rejects mismatched type and map")
    func rejectsMismatches() {
        #expect(throws: StarkProtocolError.unexpectedConfigurationType(expected: 0, actual: 8)) {
            try StarkPowerModeConfigurationCommand.decodeResponse(
                Data([0, 8, 0, 1, 100, 0, 0, 0, 0]),
                expectedMapIndex: 1
            )
        }
        #expect(throws: StarkProtocolError.unexpectedMapIndex(expected: 1, actual: 2)) {
            try StarkPowerModeConfigurationCommand.decodeResponse(
                Data([0, 0, 0, 2, 100, 0, 0, 0, 0]),
                expectedMapIndex: 1
            )
        }
    }

    @Test("Traction firmware gate starts at 1.10.1")
    func tractionFirmwareGate() {
        #expect(StarkFirmwareVersion("1.10.0")?.isTractionControlCompatible == false)
        #expect(StarkFirmwareVersion("1.10.1")?.isTractionControlCompatible == true)
        #expect(StarkFirmwareVersion("1.12.0")?.isTractionControlCompatible == true)
    }

    @Test("Rejects invalid envelope, status and short payload")
    func rejectsInvalidEnvelope() {
        #expect(throws: StarkProtocolError.unexpectedConfigurationOperation(expected: 0, actual: 1)) {
            try StarkTractionControlConfigurationCommand.decodeResponse(
                Data([1, 8, 0, 0, 0, 0, 0, 0]),
                expectedMapIndex: 0
            )
        }
        #expect(throws: StarkProtocolError.configurationRequestFailed(status: 2)) {
            try StarkTractionControlConfigurationCommand.decodeResponse(
                Data([0, 8, 2, 0, 0, 0, 0, 0]),
                expectedMapIndex: 0
            )
        }
        #expect(throws: StarkProtocolError.payloadTooShort(expected: 8, actual: 7)) {
            try StarkTractionControlConfigurationCommand.decodeResponse(
                Data([0, 8, 0, 0, 0, 0, 0]),
                expectedMapIndex: 0
            )
        }
    }
}
