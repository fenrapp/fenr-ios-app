public enum RideNavigationTrailDirection: Equatable, Sendable {
    case forward
    case reverse

    public var title: String {
        return switch self {
        case .forward: String(localized: .rideNavigationDirectionForward)
        case .reverse: String(localized: .rideNavigationDirectionReverse)
        }
    }

    public var systemImage: String {
        return switch self {
        case .forward: "arrow.up"
        case .reverse: "arrow.uturn.down"
        }
    }
}
