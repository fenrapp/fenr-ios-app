import Foundation

enum BikeEmulatorPowerModeError: LocalizedError {
    case readFailure
    case controlNotPrepared
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .readFailure: "Simulated 4005 read timeout"
        case .controlNotPrepared: "Power mode control has not passed the debug no-op guard"
        case .invalidConfiguration: "Power mode configuration is outside the supported range"
        }
    }
}
