import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct ChargingLiveActivityAttributes: ActivityAttributes {
    typealias ContentState = ChargingLiveActivityContentState

    var vin: String
}

struct ChargingLiveActivityContentState: Codable, Hashable {
    var batteryPercent: Int?
    var targetPercent: Int?
    var estimatedTimeRemaining: String?
    var powerText: String?
    var currentText: String?
    var temperatureText: String?
    var phase: ChargingLiveActivityPhase
}

enum ChargingLiveActivityPhase: String, Codable, Hashable {
    case charging
    case balancing
    case complete
    case stale
    case connectionLost

    var displayTitle: String {
        switch self {
        case .charging:
            "Charging"
        case .balancing:
            "Balancing"
        case .complete:
            "Charge complete"
        case .stale:
            "Waiting for update"
        case .connectionLost:
            "Connection lost"
        }
    }
}
