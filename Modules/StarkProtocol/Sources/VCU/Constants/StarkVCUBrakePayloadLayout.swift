public enum StarkVCUBrakePayloadLayout {
    public static let header = [UInt8(0x05), 0x0F]
    public static let minimumLength = 8
    public static let primaryBrakeSignalOffset = 2
    public static let secondaryBrakeSignalOffset = 6
}
