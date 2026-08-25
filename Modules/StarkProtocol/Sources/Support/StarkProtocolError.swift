public enum StarkProtocolError: Error, Equatable, Sendable {
    case payloadTooShort(expected: Int, actual: Int)
    case invalidPayloadLength(expected: Int, actual: Int)
    case invalidVIN
    case invalidNonceLength(expected: Int, actual: Int)
    case invalidMapIndex(Int)
    case unexpectedConfigurationType(expected: UInt8, actual: UInt8)
    case unexpectedMapIndex(expected: Int, actual: Int)
    case unexpectedConfigurationOperation(expected: UInt8, actual: UInt8)
    case configurationRequestFailed(status: UInt8)
}
