import Foundation

public struct StarkLiveTotalsDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkLiveTotalsPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkLiveTotalsPayloadLayout.requiredLength)

        return StarkLiveTotalsPayload(
            firstRawCounter: reader.u32(at: StarkLiveTotalsPayloadLayout.firstCounterOffset),
            secondRawCounter: reader.u32(at: StarkLiveTotalsPayloadLayout.secondCounterOffset),
            thirdRawCounter: reader.u32(at: StarkLiveTotalsPayloadLayout.thirdCounterOffset),
            fourthRawCounter: reader.u32(at: StarkLiveTotalsPayloadLayout.fourthCounterOffset)
        )
    }
}
