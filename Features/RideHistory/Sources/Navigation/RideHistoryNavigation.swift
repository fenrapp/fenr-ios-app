import Foundation

public enum RideHistoryDestination: Hashable, Sendable {
    case overview
    case detail(id: UUID)
}

public enum RideHistoryNavigationEvent: Equatable, Sendable {
    case show(RideHistoryDestination)
}
