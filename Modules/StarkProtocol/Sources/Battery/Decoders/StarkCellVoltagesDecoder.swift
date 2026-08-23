import Foundation

public struct StarkCellVoltagesDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkCellVoltagesPayload {
        guard data.count == StarkBatteryPayloadLayout.cellVoltagesLength else {
            throw StarkProtocolError.invalidPayloadLength(
                expected: StarkBatteryPayloadLayout.cellVoltagesLength,
                actual: data.count
            )
        }
        let reader = StarkByteReader(data: data)
        let volts = (0 ..< StarkBatteryPayloadLayout.cellVoltageCount).map { index in
            let offset = index * StarkBatteryPayloadLayout.cellVoltageByteWidth
            return Double(reader.u16(at: offset)) / StarkBatteryPayloadLayout.cellVoltageScale
        }
        return StarkCellVoltagesPayload(volts: volts)
    }
}
