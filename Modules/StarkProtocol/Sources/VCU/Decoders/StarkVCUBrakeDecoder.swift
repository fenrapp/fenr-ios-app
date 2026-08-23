import Foundation

public struct StarkVCUBrakeDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkVCUBrakePayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkVCUBrakePayloadLayout.minimumLength)

        return StarkVCUBrakePayload(
            primaryBrakeSignal: reader.u16(at: StarkVCUBrakePayloadLayout.primaryBrakeSignalOffset),
            secondaryBrakeSignal: reader.u16(at: StarkVCUBrakePayloadLayout.secondaryBrakeSignalOffset)
        )
    }
}
