import RideNavigation
import SwiftUI

struct FocusNavigationPalette {
    let backgroundWhiteLevel: Double
    let routeWhiteLevel: Double
    let futureRouteWhiteLevel: Double
    let completedRouteWhiteLevel: Double
    let recordedRouteWhiteLevel: Double
    let riderWhiteLevel: Double
    let riderOutlineWhiteLevel: Double
    let directionalIndicatorWhiteLevel: Double
    let neutralMarkerWhiteLevel: Double

    init(colorScheme: ColorScheme) {
        backgroundWhiteLevel = Self.resolvedWhiteLevel(.zero, colorScheme: colorScheme)
        routeWhiteLevel = Self.resolvedWhiteLevel(1, colorScheme: colorScheme)
        futureRouteWhiteLevel = Self.resolvedWhiteLevel(0.72, colorScheme: colorScheme)
        completedRouteWhiteLevel = Self.resolvedWhiteLevel(0.35, colorScheme: colorScheme)
        recordedRouteWhiteLevel = Self.resolvedWhiteLevel(0.7, colorScheme: colorScheme)
        riderWhiteLevel = Self.resolvedWhiteLevel(1, colorScheme: colorScheme)
        riderOutlineWhiteLevel = Self.resolvedWhiteLevel(0.35, colorScheme: colorScheme)
        directionalIndicatorWhiteLevel = Self.resolvedWhiteLevel(1, colorScheme: colorScheme)
        neutralMarkerWhiteLevel = Self.resolvedWhiteLevel(0.55, colorScheme: colorScheme)
    }

    var background: Color { Color(white: backgroundWhiteLevel) }
    var rider: Color { Color(white: riderWhiteLevel) }
    var riderOutline: Color { Color(white: riderOutlineWhiteLevel) }
    var directionalIndicator: Color { Color(white: directionalIndicatorWhiteLevel) }
    var compassRing: Color { Color(white: riderWhiteLevel) }
    var compassSecondary: Color { Color(white: neutralMarkerWhiteLevel) }
    var compassNorthGradient: Gradient { Gradient(colors: [.red, .orange]) }

    func polylineColor(for role: NavigationMapPolylineRole) -> Color {
        switch role {
        case .planned, .trailActive, .approach, .rejoinGuide:
            Color(white: routeWhiteLevel)
        case .trailFuture:
            Color(white: futureRouteWhiteLevel)
        case .trailCompleted, .completed:
            Color(white: completedRouteWhiteLevel)
        case .recorded:
            Color(white: recordedRouteWhiteLevel)
        }
    }

    func markerColor(for role: NavigationMapMarkerRole) -> Color {
        switch role {
        case .start:
            .green
        case .finish:
            .red
        case .waypoint, .participant:
            Color(white: neutralMarkerWhiteLevel)
        }
    }

    private static func resolvedWhiteLevel(
        _ darkModeWhiteLevel: Double,
        colorScheme: ColorScheme
    ) -> Double {
        switch colorScheme {
        case .dark:
            darkModeWhiteLevel
        case .light:
            1 - darkModeWhiteLevel
        @unknown default:
            darkModeWhiteLevel
        }
    }
}
