public enum StarkStatusPayloadLayout {
    public static let requiredLength = 18
    public static let miscBitsOffset = 0
    public static let indicatorBitsOffset = 2
    public static let alertBitsOffset = 4
    public static let faultBitsOffset = 6
    public static let infoBitsOffset = 8
    public static let lockStatusOffset = 10
    public static let lockTimeOffset = 11
    public static let updateAvailableOffset = 13
    public static let batteryStatusOffset = 14
}
