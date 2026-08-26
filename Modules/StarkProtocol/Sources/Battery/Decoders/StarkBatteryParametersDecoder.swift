import Foundation

public struct StarkBatteryParametersDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkBatteryParametersPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkBatteryParametersPayloadLayout.requiredLength)

        return StarkBatteryParametersPayload(
            seriesCount: Int(reader.u8(at: StarkBatteryParametersPayloadLayout.seriesOffset)),
            parallelCount: Int(reader.u8(at: StarkBatteryParametersPayloadLayout.parallelOffset)),
            capacityRaw: Int(reader.u16(at: StarkBatteryParametersPayloadLayout.capacityOffset))
        )
    }
}
