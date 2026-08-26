import Foundation

public struct StarkLiveEstimationsDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkLiveEstimationsPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkLiveEstimationsPayloadLayout.requiredLength)

        return StarkLiveEstimationsPayload(
            estimatedRangeRaw: Int(reader.u16(at: StarkLiveEstimationsPayloadLayout.estimatedRangeOffset)),
            estimatedTimeRaw: Int(reader.u16(at: StarkLiveEstimationsPayloadLayout.estimatedTimeOffset)),
            nativeMotorPowerRaw: Int(reader.i16(at: StarkLiveEstimationsPayloadLayout.motorPowerOffset))
        )
    }
}
