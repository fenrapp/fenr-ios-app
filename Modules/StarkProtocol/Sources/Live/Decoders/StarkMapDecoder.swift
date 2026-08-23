import Foundation

public struct StarkMapDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkMapPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkMapPayloadLayout.requiredLength)
        return StarkMapPayload(modeIndex: Int(reader.u8(at: StarkMapPayloadLayout.modeOffset)))
    }
}
