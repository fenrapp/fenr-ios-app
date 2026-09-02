import ActivityKit

struct BikeLiveActivityAttributes: ActivityAttributes {
    typealias ContentState = BikeLiveActivityContentState

    var vin: String
}

struct BikeLiveActivityContentState: Codable, Hashable {
    var batteryPercent: Int?
    var targetPercent: Int?
    var estimatedTimeRemaining: String?
    var powerText: String?
    var currentText: String?
    var temperatureText: String?
    var modeIndex: Int?
    var speedText: String?
    var runState: BikeLiveActivityRunState
    var mode: BikeLiveActivityMode
    var phase: BikeLiveActivityPhase
    var isFaultActive: Bool
    var isConnectionLost: Bool
}

enum BikeLiveActivityMode: String, Codable, Hashable {
    case charging
    case riding
    case connectionLost
    case stale
}

enum BikeLiveActivityRunState: String, Codable, Hashable {
    case unknown
    case off
    case neutral
    case ride
    case charging
    case crawlForward
    case crawlReverse

}

enum BikeLiveActivityPhase: String, Codable, Hashable {
    case charging
    case balancing
    case complete
    case riding
    case neutral
    case crawl
    case fault
    case reconnecting
    case stale
    case connectionLost

}
