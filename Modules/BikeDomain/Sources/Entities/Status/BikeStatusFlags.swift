public struct BikeStatusFlags: Equatable, Sendable {
    public let isOn: Bool
    public let isCharging: Bool
    public let isChargerConnected: Bool
    public let isInGear: Bool
    public let isFaultActive: Bool
    public let isBrakeActive: Bool
    public let crawlState: BikeCrawlState
    public let indicatorState: BikeIndicatorState

    public static let unknown = BikeStatusFlags(crawlState: .unknown)

    public init(
        isOn: Bool = false,
        isCharging: Bool = false,
        isChargerConnected: Bool = false,
        isInGear: Bool = false,
        isFaultActive: Bool = false,
        isBrakeActive: Bool = false,
        crawlState: BikeCrawlState = .inactive,
        indicatorState: BikeIndicatorState = .init()
    ) {
        self.isOn = isOn
        self.isCharging = isCharging
        self.isChargerConnected = isChargerConnected
        self.isInGear = isInGear
        self.isFaultActive = isFaultActive
        self.isBrakeActive = isBrakeActive
        self.crawlState = crawlState
        self.indicatorState = indicatorState
    }
}
