public enum StarkInverterTemperaturesPayloadLayout {
    public static let groupCount = 2
    public static let temperaturesPerGroup = 3
    public static let temperatureCount = groupCount * temperaturesPerGroup
    public static let temperatureByteWidth = 2
    public static let validStatusOffset = temperaturesPerGroup * temperatureByteWidth
    public static let usedStatusOffset = validStatusOffset + 1
    public static let groupByteWidth = usedStatusOffset + 1
    public static let requiredLength = groupCount * groupByteWidth
    public static let temperatureScale = 10.0
    public static let unavailableRawValue: UInt16 = 0
}
