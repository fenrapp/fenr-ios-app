import DesignSystem
import SwiftUI

nonisolated struct DashboardChargingBorderPalette {
    let border: Color
    let normal: Colors
    let balancing: Colors
    let progressGlowOpacity: Double
    let pulseMaximumOpacity: Double

    static func resolve(in environment: EnvironmentValues) -> Self {
        let isDark = environment.colorScheme != .light
        let balancingHead = (isDark ? Color.cyan : DashboardSemanticColor.lightBalancing).resolve(in: environment)
        let informational = DesignColor.informational.resolve(in: environment)
        return Self(
            border: Color(DesignColor.border.resolve(in: environment)),
            normal: Colors(
                start: isDark ? informational : Constants.lightInformational.resolve(in: environment),
                middle: (isDark ? DesignColor.positive : Constants.lightPositive).resolve(in: environment),
                head: (isDark ? Color.mint : Constants.lightPositive).resolve(in: environment),
                glow: informational
            ),
            balancing: Colors(
                start: balancingHead,
                middle: (isDark ? Color.indigo : Constants.lightBalancingMiddle).resolve(in: environment),
                head: balancingHead,
                glow: balancingHead
            ),
            progressGlowOpacity: isDark ? Constants.darkProgressGlowOpacity : Constants.lightProgressGlowOpacity,
            pulseMaximumOpacity: isDark ? Constants.darkPulseMaximumOpacity : Constants.lightPulseMaximumOpacity
        )
    }

    func colors(at fraction: Double) -> Colors {
        if fraction <= .zero { return normal }
        if fraction >= 1 { return balancing }
        return Colors(
            start: blend(normal.start, balancing.start, fraction),
            middle: blend(normal.middle, balancing.middle, fraction),
            head: blend(normal.head, balancing.head, fraction),
            glow: blend(normal.glow, balancing.glow, fraction)
        )
    }

    private func blend(_ normal: Color.Resolved, _ target: Color.Resolved, _ fraction: Double) -> Color.Resolved {
        var resolved = normal
        let fraction = Float(fraction)
        resolved.linearRed += (target.linearRed - resolved.linearRed) * fraction
        resolved.linearGreen += (target.linearGreen - resolved.linearGreen) * fraction
        resolved.linearBlue += (target.linearBlue - resolved.linearBlue) * fraction
        resolved.opacity += (target.opacity - resolved.opacity) * fraction
        return resolved
    }

    struct Colors {
        let start: Color.Resolved
        let middle: Color.Resolved
        let head: Color.Resolved
        let glow: Color.Resolved
    }

    private enum Constants {
        static let darkProgressGlowOpacity = 0.46
        static let lightProgressGlowOpacity = 0.2
        static let darkPulseMaximumOpacity = 0.46
        static let lightPulseMaximumOpacity = 0.3
        static let lightInformational = Color(red: 0, green: 0.64, blue: 0.68)
        static let lightPositive = Color(red: 0.1, green: 0.7, blue: 0.3)
        static let lightBalancingMiddle = Color(red: 0.26, green: 0.56, blue: 0.96)
    }
}
