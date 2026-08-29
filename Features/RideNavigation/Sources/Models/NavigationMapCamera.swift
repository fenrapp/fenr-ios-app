import EnvironmentDomain

public enum NavigationMapCamera: Equatable, Sendable {
    case automatic
    case follow(coordinate: GeographicCoordinate, headingDegrees: Double?)
    case overview([GeographicCoordinate])
    case userControlled
}
