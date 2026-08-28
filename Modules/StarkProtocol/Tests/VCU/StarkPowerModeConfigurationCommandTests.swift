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

    @Test("Encodes complete base-map writes with save flag and signed little-endian values")
    func encodesWrites() throws {
        #expect(try StarkPowerModeConfigurationCommand.writePacket(
            mapIndex: 3,
            horsepower: 80,
            regenerativeBrakingPercent: -100,
            curve: 4
        ) == Data([1, 0, 3, 1, 100, 0, 0x9C, 0xFF, 4]))

        let configuration = StarkPowerModeConfigurationPayload(
            mapIndex: 1,
            torqueRaw: 44,
            regenerationRaw: 35,
            curve: 0
        )
        #expect(try StarkPowerModeConfigurationCommand.noOpWritePacket(
            configuration: configuration
        ) == Data([1, 0, 1, 1, 44, 0, 35, 0, 2]))
    }

    @Test("Accepts observed read selectors and normalizes the write selector")
    func normalizesCurveSelector() throws {
        #expect(StarkPowerModeConfigurationCommand.isSupportedReadCurve(0, mapIndex: 2))
        #expect(StarkPowerModeConfigurationCommand.isSupportedReadCurve(3, mapIndex: 2))
        #expect(!StarkPowerModeConfigurationCommand.isSupportedReadCurve(9, mapIndex: 2))
        #expect(try StarkPowerModeConfigurationCommand.normalizedWriteCurve(mapIndex: 2) == 3)
    }

    @Test("Encodes whole-percent traction writes with the official mode field")
    func encodesTractionControlWrites() throws {
        #expect(try StarkTractionControlConfigurationCommand.writePacket(
            mapIndex: 3,
            powerTractionPercent: 12,
            brakingTractionPercent: 30
        ) == Data([1, 8, 1, 3, 15, 0x78, 0, 0x2C, 0x01]))

        let configuration = StarkTractionControlConfigurationPayload(
            mapIndex: 1,
            powerRaw: 200,
            brakingRaw: 250
        )
        #expect(try StarkTractionControlConfigurationCommand.noOpWritePacket(
            configuration: configuration
        ) == Data([1, 8, 1, 1, 15, 0xC8, 0, 0xFA, 0]))
    }

    @Test("Rejects traction-control percentages outside the guarded range")
    func rejectsInvalidTractionControlWrites() {
        #expect(throws: StarkProtocolError.invalidTractionControlPercent(100.1)) {
            try StarkTractionControlConfigurationCommand.writePacket(
                mapIndex: 0,
                powerTractionPercent: 100.1,
                brakingTractionPercent: 0
            )
        }
        #expect(throws: StarkProtocolError.invalidTractionControlPercent(12.5)) {
            try StarkTractionControlConfigurationCommand.writePacket(
                mapIndex: 0,
                powerTractionPercent: 12.5,
                brakingTractionPercent: 0
            )
        }
        #expect(throws: StarkProtocolError.invalidTractionControlRawValue(125)) {
            try StarkTractionControlConfigurationCommand.noOpWritePacket(
                configuration: .init(mapIndex: 0, powerRaw: 125, brakingRaw: 200)
            )
        }
    }

    @Test("Rejects power-mode writes outside the guarded ranges")
    func rejectsInvalidWrites() {
        #expect(throws: StarkProtocolError.invalidPowerModeHorsepower(81)) {
            try StarkPowerModeConfigurationCommand.writePacket(
                mapIndex: 0,
                horsepower: 81,
                regenerativeBrakingPercent: 0,
                curve: 1
            )
        }
        #expect(throws: StarkProtocolError.invalidRegenerativeBrakingPercent(101)) {
            try StarkPowerModeConfigurationCommand.writePacket(
                mapIndex: 0,
                horsepower: 60,
                regenerativeBrakingPercent: 101,
                curve: 1
            )
        }
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
        #expect(payload.curve == 0)
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
