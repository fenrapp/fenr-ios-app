public enum StarkInverterTemperaturesPayloadLayout {
    public static let temperatureCount = 8
    public static let temperatureByteWidth = 2
    public static let requiredLength = temperatureCount * temperatureByteWidth
    public static let temperatureScale = 10.0
    public static let unavailableRawValue: UInt16 = 0
}
