import DesignSystem
import SwiftUI

struct DashboardSpeedProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let extendedWidth = proxy.size.width + (Constants.horizontalOverflow * 2)
            let progressWidth = extendedWidth * clampedProgress
            LinearGradient(
                colors: [
                    gradientColors.informational,
                    gradientColors.positive,
                    gradientColors.warning
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: extendedWidth, alignment: .leading)
            .mask(alignment: .leading) {
                Capsule()
                    .frame(width: progressWidth)
            }
            .animation(
                reduceMotion ? nil : .linear(duration: Constants.animationDuration),
                value: progressWidth
            )
            .offset(x: -Constants.horizontalOverflow)
        }
        .frame(height: Constants.height)
        .accessibilityHidden(true)
    }

    private var clampedProgress: Double {
        min(max(progress, .zero), 1)
    }

    private var gradientColors: GradientColors {
        switch colorScheme {
        case .dark:
            .init(
                informational: DesignColor.informational,
                positive: DesignColor.positive,
                warning: DesignColor.warning
            )
        case .light:
            .init(
                informational: Constants.lightInformational,
                positive: Constants.lightPositive,
                warning: Constants.lightWarning
            )
        @unknown default:
            .init(
                informational: DesignColor.informational,
                positive: DesignColor.positive,
                warning: DesignColor.warning
            )
        }
    }

    private struct GradientColors {
        let informational: Color
        let positive: Color
        let warning: Color
    }

    private enum Constants {
        static let height: CGFloat = 3
        static let horizontalOverflow: CGFloat = 24
        static let animationDuration = 0.32
        static let lightInformational = Color(red: 0, green: 0.48, blue: 0.52)
        static let lightPositive = Color(red: 0.04, green: 0.5, blue: 0.18)
        static let lightWarning = Color(red: 0.82, green: 0.32, blue: 0)
    }
}
