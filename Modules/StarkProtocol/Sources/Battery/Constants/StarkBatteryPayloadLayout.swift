public enum StarkBatteryPayloadLayout {
    public static let minimumLength = 2
    public static let lengthWithStateOfHealth = 4
    public static let lengthWithDCBus = 6
    public static let stateOfChargeOffset = 0
    public static let stateOfHealthOffset = 2
    public static let dcBusOffset = 4

    public static let cellVoltageCount = 100
    public static let cellVoltageByteWidth = 2
    public static let cellVoltagesLength = cellVoltageCount * cellVoltageByteWidth
    public static let cellVoltageScale = 10_000.0

    public static let temperatureCount = 12
    public static let temperatureByteWidth = 2
    public static let temperaturesDataLength = temperatureCount * temperatureByteWidth
    public static let temperaturesValidMaskOffset = temperaturesDataLength
    public static let temperaturesUsedOffset = temperaturesValidMaskOffset + temperatureByteWidth
    public static let temperaturesLength = temperaturesUsedOffset + 1
    public static let temperatureScale = 10.0

    public static let balancingLength = 13
    public static let balancingBitsPerByte = 8
}
