import DesignSystem
import SwiftUI

struct ChargingDashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(
                x: proxy.size.width / 2,
                y: proxy.size.height * Constants.centerHeightRatio
            )
            let diameter = max(proxy.size.width, proxy.size.height) * Constants.diameterRatio

            ZStack {
                RadialGradient(
                    colors: [
                        DesignColor.informational.opacity(baseGlowOpacity),
                        .clear
                    ],
                    center: .center,
                    startRadius: .zero,
                    endRadius: diameter / 2
                )
                .frame(width: diameter, height: diameter)
                .position(center)

                ForEach(Array(Constants.energyPositions.enumerated()), id: \.offset) { _, position in
                    energyMark(position: position, size: proxy.size)
                }
            }
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    private var baseGlowOpacity: Double {
        colorScheme == .dark ? Constants.darkGlowOpacity : Constants.lightGlowOpacity
    }

    private func energyMark(position: EnergyPosition, size: CGSize) -> some View {
        return Capsule()
            .fill(DesignColor.informational.opacity(pulseOpacity))
            .frame(width: Constants.pulseWidth, height: Constants.pulseHeight)
            .rotationEffect(.degrees(Constants.pulseAngleDegrees))
            .shadow(
                color: DesignColor.informational.opacity(pulseOpacity),
                radius: Constants.pulseGlowRadius
            )
            .position(
                x: size.width * position.horizontal,
                y: size.height * position.vertical
            )
    }

    private var pulseOpacity: Double {
        colorScheme == .dark ? Constants.darkPulseOpacity : Constants.lightPulseOpacity
    }

    private struct EnergyPosition: Hashable {
        let horizontal: CGFloat
        let vertical: CGFloat
    }

    private enum Constants {
        static let centerHeightRatio = 0.62
        static let diameterRatio: CGFloat = 0.82
        static let lightGlowOpacity = 0.09
        static let darkGlowOpacity = 0.16
        static let lightPulseOpacity = 0.2
        static let darkPulseOpacity = 0.34
        static let energyPositions = [
            EnergyPosition(horizontal: 0.28, vertical: 0.68),
            EnergyPosition(horizontal: 0.38, vertical: 0.6),
            EnergyPosition(horizontal: 0.48, vertical: 0.7),
            EnergyPosition(horizontal: 0.57, vertical: 0.57),
            EnergyPosition(horizontal: 0.67, vertical: 0.66)
        ]
        static let pulseWidth: CGFloat = 2
        static let pulseHeight: CGFloat = 34
        static let pulseAngleDegrees = -24.0
        static let pulseGlowRadius: CGFloat = 8
    }
}
