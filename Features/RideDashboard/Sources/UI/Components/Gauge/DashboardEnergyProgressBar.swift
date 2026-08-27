import DesignSystem
import SwiftUI

struct DashboardEnergyProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let regenerationProgress: Double
    let consumptionProgress: Double

    var body: some View {
        GeometryReader { proxy in
            let extendedWidth = proxy.size.width + (Constants.horizontalOverflow * 2)
            let halfWidth = extendedWidth / 2
            ZStack {
                Capsule()
                    .fill(DesignColor.inactive)
                    .frame(width: extendedWidth, height: Constants.trackHeight)

                HStack(spacing: .zero) {
                    regenerationGradient
                        .frame(width: halfWidth)
                        .mask(alignment: .trailing) {
                            Capsule()
                                .frame(width: halfWidth * clampedRegenerationProgress)
                        }

                    consumptionGradient
                        .frame(width: halfWidth)
                        .mask(alignment: .leading) {
                            Capsule()
                                .frame(width: halfWidth * clampedConsumptionProgress)
                        }
                }
                .frame(width: extendedWidth)

                Capsule()
                    .fill(DesignColor.secondaryText.opacity(Constants.centerMarkerOpacity))
                    .frame(width: Constants.centerMarkerWidth, height: Constants.centerMarkerHeight)
            }
            .frame(width: extendedWidth, height: Constants.centerMarkerHeight)
            .animation(
                reduceMotion ? nil : .linear(duration: Constants.animationDuration),
                value: clampedRegenerationProgress
            )
            .animation(
                reduceMotion ? nil : .linear(duration: Constants.animationDuration),
                value: clampedConsumptionProgress
            )
            .offset(x: -Constants.horizontalOverflow)
        }
        .frame(height: Constants.centerMarkerHeight)
    }

    private var regenerationGradient: LinearGradient {
        LinearGradient(
            colors: [colors.regeneration, colors.regeneration.opacity(Constants.centerColorOpacity)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var consumptionGradient: LinearGradient {
        LinearGradient(
            colors: [colors.consumption.opacity(Constants.centerColorOpacity), colors.consumption],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var clampedRegenerationProgress: Double {
        min(max(regenerationProgress, .zero), 1)
    }

    private var clampedConsumptionProgress: Double {
        min(max(consumptionProgress, .zero), 1)
    }

    private var colors: GradientColors {
        switch colorScheme {
        case .dark:
            .init(regeneration: DesignColor.positive, consumption: DesignColor.warning)
        case .light:
            .init(regeneration: Constants.lightRegeneration, consumption: Constants.lightConsumption)
        @unknown default:
            .init(regeneration: DesignColor.positive, consumption: DesignColor.warning)
        }
    }

    private struct GradientColors {
        let regeneration: Color
        let consumption: Color
    }

    private enum Constants {
        static let trackHeight: CGFloat = 3
        static let centerMarkerWidth: CGFloat = 2
        static let centerMarkerHeight: CGFloat = 7
        static let horizontalOverflow: CGFloat = 24
        static let centerMarkerOpacity = 0.7
        static let centerColorOpacity = 0.32
        static let animationDuration = 0.32
        static let lightRegeneration = Color(red: 0.04, green: 0.5, blue: 0.18)
        static let lightConsumption = Color(red: 0.82, green: 0.32, blue: 0)
    }
}
