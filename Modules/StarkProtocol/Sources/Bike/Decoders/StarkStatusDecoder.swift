import Foundation

public struct StarkStatusDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkStatusPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkStatusPayloadLayout.requiredLength)

        return StarkStatusPayload(
            miscBits: reader.u16(at: StarkStatusPayloadLayout.miscBitsOffset),
            indicatorBits: reader.u16(at: StarkStatusPayloadLayout.indicatorBitsOffset),
            alertBits: reader.u16(at: StarkStatusPayloadLayout.alertBitsOffset),
            faultBits: reader.u16(at: StarkStatusPayloadLayout.faultBitsOffset),
            infoBits: reader.u16(at: StarkStatusPayloadLayout.infoBitsOffset),
            lockStatus: reader.u8(at: StarkStatusPayloadLayout.lockStatusOffset),
            lockTime: reader.u16(at: StarkStatusPayloadLayout.lockTimeOffset),
            updateAvailable: reader.u8(at: StarkStatusPayloadLayout.updateAvailableOffset) == StarkPayloadValue.enabled,
            batteryStatus: reader.u32(at: StarkStatusPayloadLayout.batteryStatusOffset)
        )
    }
}
