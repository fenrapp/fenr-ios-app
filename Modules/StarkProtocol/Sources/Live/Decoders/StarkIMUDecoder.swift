import Foundation

public struct StarkIMUDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkIMUPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkIMUPayloadLayout.requiredLength)

        return StarkIMUPayload(
            accelerationXRaw: Int(reader.i16(at: StarkIMUPayloadLayout.accelerationXOffset)),
            accelerationYRaw: Int(reader.i16(at: StarkIMUPayloadLayout.accelerationYOffset)),
            accelerationZRaw: Int(reader.i16(at: StarkIMUPayloadLayout.accelerationZOffset)),
            gyroscopeXRaw: Int(reader.i16(at: StarkIMUPayloadLayout.gyroscopeXOffset)),
            gyroscopeYRaw: Int(reader.i16(at: StarkIMUPayloadLayout.gyroscopeYOffset)),
            gyroscopeZRaw: Int(reader.i16(at: StarkIMUPayloadLayout.gyroscopeZOffset))
        )
    }
}
