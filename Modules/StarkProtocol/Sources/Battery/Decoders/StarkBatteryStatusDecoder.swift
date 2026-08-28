import Foundation

public struct StarkBatteryStatusDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkBatteryStatusPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkBatteryStatusPayloadLayout.requiredLength)

        return StarkBatteryStatusPayload(
            positiveFaultBits: reader.u32(at: StarkBatteryStatusPayloadLayout.positiveFaultBitsOffset),
            negativeFaultBits: reader.u32(at: StarkBatteryStatusPayloadLayout.negativeFaultBitsOffset)
        )
    }
}
