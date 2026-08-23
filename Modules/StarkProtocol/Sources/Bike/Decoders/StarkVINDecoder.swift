import Foundation

public struct StarkVINDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkVINPayload {
        let reader = StarkByteReader(data: data)
        try reader.require(StarkVINPayloadLayout.minimumLength)

        let bytes = data.prefix(StarkVINPayloadLayout.maximumLength).filter { $0 != StarkPayloadValue.disabled }
        let vin = String(bytes: bytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let vin, !vin.isEmpty else {
            throw StarkProtocolError.invalidVIN
        }
        return StarkVINPayload(value: vin)
    }
}
