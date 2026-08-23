public enum StarkProtocolError: Error, Equatable, Sendable {
    case payloadTooShort(expected: Int, actual: Int)
    case invalidPayloadLength(expected: Int, actual: Int)
    case invalidVIN
    case invalidNonceLength(expected: Int, actual: Int)
}
