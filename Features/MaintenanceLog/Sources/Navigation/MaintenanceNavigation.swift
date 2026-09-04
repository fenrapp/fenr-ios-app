import Foundation

public enum MaintenanceDestination: Hashable, Sendable {
    case overview
    case detail(id: UUID)
    case form(id: UUID?)
}

public enum MaintenanceNavigationEvent: Equatable, Sendable {
    case show(MaintenanceDestination)
    case close(MaintenanceDestination)
}
