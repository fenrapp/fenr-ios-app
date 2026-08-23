public struct BikeRawStatusFlags: Equatable, Sendable {
    public let misc: Int
    public let indicator: Int
    public let alert: Int
    public let fault: Int
    public let info: Int

    public static let unknown = BikeRawStatusFlags()

    public init(
        misc: Int = 0,
        indicator: Int = 0,
        alert: Int = 0,
        fault: Int = 0,
        info: Int = 0
    ) {
        self.misc = misc
        self.indicator = indicator
        self.alert = alert
        self.fault = fault
        self.info = info
    }
}
