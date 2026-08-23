import BikeDomain

public struct BikeRunStateToBadgeMapper: Sendable {
    public init() {}

    public func map(_ runState: BikeRunState) -> String {
        switch runState {
        case .unknown:
            "Unknown"
        case .off:
            "Off"
        case .neutral:
            "Neutral"
        case .on:
            "On"
        case .charging:
            "Charging"
        case .crawlForward:
            "Crawl FWD"
        case .crawlReverse:
            "Crawl REV"
        }
    }
}
