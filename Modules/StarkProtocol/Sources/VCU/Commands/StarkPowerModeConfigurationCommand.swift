import Foundation

public enum StarkPowerModeConfigurationCommand {
    public static let mapIndexes = 0 ... 4
    public static let configurationType: UInt8 = 0
    public static let responseLength = 9

    public static func readPacket(mapIndex: Int) throws -> Data {
        guard mapIndexes.contains(mapIndex) else {
            throw StarkProtocolError.invalidMapIndex(mapIndex)
        }
        return Data([0, configurationType, UInt8(mapIndex)])
    }

    public static func decodeResponse(
        _ data: Data,
        expectedMapIndex: Int
    ) throws -> StarkPowerModeConfigurationPayload {
        try requireMapIndex(expectedMapIndex)
        guard data.count >= responseLength else {
            throw StarkProtocolError.payloadTooShort(expected: responseLength, actual: data.count)
        }
        let reader = StarkByteReader(data: data)
        let operation = reader.u8(at: 0)
        guard operation == 0 || operation == 2 else {
            throw StarkProtocolError.unexpectedConfigurationOperation(expected: 0, actual: operation)
        }
        let type = reader.u8(at: 1)
        guard type == configurationType else {
            throw StarkProtocolError.unexpectedConfigurationType(expected: configurationType, actual: type)
        }
        let status = reader.u8(at: 2)
        guard status == 0 else {
            throw StarkProtocolError.configurationRequestFailed(status: status)
        }
        let mapIndex = Int(reader.u8(at: 3))
        guard mapIndex == expectedMapIndex else {
            throw StarkProtocolError.unexpectedMapIndex(expected: expectedMapIndex, actual: mapIndex)
        }
        return StarkPowerModeConfigurationPayload(
            mapIndex: mapIndex,
            torqueRaw: Int(reader.i16(at: 4)),
            regenerationRaw: Int(reader.i16(at: 6)),
            curve: Int(reader.u8(at: 8))
        )
    }

    private static func requireMapIndex(_ mapIndex: Int) throws {
        guard mapIndexes.contains(mapIndex) else {
            throw StarkProtocolError.invalidMapIndex(mapIndex)
        }
    }
}
