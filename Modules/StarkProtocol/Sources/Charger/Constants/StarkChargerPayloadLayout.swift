public enum StarkChargerPayloadLayout {
    public static let length = 19

    public static let requestedCurrentOffset = 0
    public static let reportedCurrentOffset = 2
    public static let targetCellVoltageOffset = 4
    public static let maximumCurrentOffset = 6
    public static let maximumPowerOffset = 8
    public static let maximumStateOfChargeOffset = 10
    public static let requestedVoltageOffset = 12
    public static let reportedVoltageOffset = 14
    public static let statusOffset = 16
    public static let enabledOffset = 17
    public static let typeOffset = 18

    public static let currentScale = 10.0
    public static let cellVoltageScale = 10_000.0
}
