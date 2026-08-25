import Foundation

public enum StarkTractionControlConfigurationCommand {
    public static let configurationType: UInt8 = 8
    public static let responseLength = 8

    public static func readPacket(mapIndex: Int) throws -> Data {
        guard StarkPowerModeConfigurationCommand.mapIndexes.contains(mapIndex) else {
            throw StarkProtocolError.invalidMapIndex(mapIndex)
        }
        return Data([0, configurationType, UInt8(mapIndex)])
    }

    public static func decodeResponse(
        _ data: Data,
        expectedMapIndex: Int
    ) throws -> StarkTractionControlConfigurationPayload {
        guard StarkPowerModeConfigurationCommand.mapIndexes.contains(expectedMapIndex) else {
            throw StarkProtocolError.invalidMapIndex(expectedMapIndex)
        }
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
        return StarkTractionControlConfigurationPayload(
            mapIndex: mapIndex,
            powerRaw: Int(reader.i16(at: 4)),
            brakingRaw: Int(reader.i16(at: 6))
        )
    }
}
