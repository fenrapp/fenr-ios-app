public enum StarkBatterySignalsPayloadLayout {
    public static let requiredLength = 18
    public static let positiveBMSOffset = 0
    public static let negativeBMSOffset = 8
    public static let currentOffset = 16

    public static let dcBusOffset = 0
    public static let temperatureOffset = 2
    public static let humidityOffset = 4
    public static let controlFlagsOffset = 6
}
