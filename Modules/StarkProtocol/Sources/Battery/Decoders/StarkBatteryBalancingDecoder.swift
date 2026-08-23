import Foundation

public struct StarkBatteryBalancingDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkBatteryBalancingPayload {
        guard data.count == StarkBatteryPayloadLayout.balancingLength else {
            throw StarkProtocolError.invalidPayloadLength(
                expected: StarkBatteryPayloadLayout.balancingLength,
                actual: data.count
            )
        }
        let reader = StarkByteReader(data: data)
        let activeCellIndexes = Set((0 ..< StarkBatteryPayloadLayout.cellVoltageCount).filter { index in
            let byteOffset = index / StarkBatteryPayloadLayout.balancingBitsPerByte
            let bitOffset = index % StarkBatteryPayloadLayout.balancingBitsPerByte
            return (reader.u8(at: byteOffset) & (1 << bitOffset)) != 0
        })
        return StarkBatteryBalancingPayload(activeCellIndexes: activeCellIndexes)
    }
}
