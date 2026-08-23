import Foundation

public struct StarkThrottleDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkThrottlePayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkThrottlePayloadLayout.requiredLength)

        return StarkThrottlePayload(
            idFeedbackRaw: Int(reader.i16(at: StarkThrottlePayloadLayout.idFeedbackOffset)),
            iqFeedbackRaw: Int(reader.i16(at: StarkThrottlePayloadLayout.iqFeedbackOffset)),
            positionRaw: Int(reader.i16(at: StarkThrottlePayloadLayout.positionOffset))
        )
    }
}
