import Foundation

public struct StarkBatteryCaptureDecoder: StarkPayloadDecoding {
    public init() {}

    public func decode(_ data: Data) throws -> StarkBatteryCapturePayload {
        guard !data.isEmpty else { throw StarkProtocolError.payloadTooShort(expected: 1, actual: 0) }
        return StarkBatteryCapturePayload(bytes: data)
    }
}
