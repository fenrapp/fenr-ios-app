import Foundation

enum NavigationCardinal: CaseIterable, Equatable {
    case north
    case east
    case south
    case west

    var resource: LocalizedStringResource {
        switch self {
        case .north: .rideNavigationAppleMapsCardinalNorth
        case .east: .rideNavigationAppleMapsCardinalEast
        case .south: .rideNavigationAppleMapsCardinalSouth
        case .west: .rideNavigationAppleMapsCardinalWest
        }
    }

    var bearingDegrees: Double {
        switch self {
        case .north: 0
        case .east: 90
        case .south: 180
        case .west: 270
        }
    }

    var isNorth: Bool { self == .north }
}
