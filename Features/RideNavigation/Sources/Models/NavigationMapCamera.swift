public enum NavigationMapCamera: Equatable, Sendable {
    case automatic
    case follow(coordinate: NavigationMapCoordinate, headingDegrees: Double?)
    case overview([NavigationMapCoordinate])
    case userControlled
}
