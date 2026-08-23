import Foundation

public struct StarkSpeedDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkSpeedPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkSpeedPayloadLayout.requiredLength)

        let speedX10 = Int(reader.i16(at: StarkSpeedPayloadLayout.speedKmhX10Offset))
        let motorRPM = Int(reader.i16(at: StarkSpeedPayloadLayout.motorRPMOffset))

        return StarkSpeedPayload(
            speedKmh: Double(speedX10) / StarkLivePayloadScale.speedKmh,
            speedKmhX10: speedX10,
            motorRPM: motorRPM
        )
    }
}
