import SwiftUI

struct OnboardingHeroAtmosphereView: View {
    let isLightPresented: Bool
    let ambientProgress: Double
    let parallaxOffset: CGSize
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                trailLight(size: proxy.size)
                if !reduceMotion {
                    trailPulse(size: proxy.size)
                    particles(size: proxy.size)
                }
            }
            .offset(parallaxOffset)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func trailLight(size: CGSize) -> some View {
        RadialGradient(
            colors: [
                .white.opacity(Constants.lightCoreOpacity),
                .white.opacity(Constants.lightEdgeOpacity),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: size.width * Constants.lightRadiusFactor
        )
        .frame(width: size.width, height: size.width)
        .scaleEffect(x: Constants.lightHorizontalScale, y: Constants.lightVerticalScale)
        .rotationEffect(.degrees(Constants.lightRotation))
        .position(x: size.width * Constants.lightX, y: size.height * Constants.lightY)
        .scaleEffect(isLightPresented ? 1 : Constants.initialLightScale)
        .opacity(isLightPresented ? 1 : 0)
        .blendMode(.screen)
    }

    private func trailPulse(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var leftTrail = Path()
            leftTrail.move(to: CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.36))
            leftTrail.addCurve(
                to: CGPoint(x: canvasSize.width * 0.2, y: canvasSize.height * 0.82),
                control1: CGPoint(x: canvasSize.width * 0.46, y: canvasSize.height * 0.52),
                control2: CGPoint(x: canvasSize.width * 0.31, y: canvasSize.height * 0.7)
            )

            var rightTrail = Path()
            rightTrail.move(to: CGPoint(x: canvasSize.width * 0.53, y: canvasSize.height * 0.36))
            rightTrail.addCurve(
                to: CGPoint(x: canvasSize.width * 0.78, y: canvasSize.height * 0.82),
                control1: CGPoint(x: canvasSize.width * 0.57, y: canvasSize.height * 0.52),
                control2: CGPoint(x: canvasSize.width * 0.69, y: canvasSize.height * 0.7)
            )

            let revealedAmount = min(1, ambientProgress * Constants.pulseRevealMultiplier)
            let opacity = max(0, 1 - ambientProgress * Constants.pulseFadeMultiplier)
            let style = StrokeStyle(lineWidth: Constants.pulseLineWidth, lineCap: .round)
            context.stroke(
                leftTrail.trimmedPath(from: 0, to: revealedAmount),
                with: .color(.white.opacity(opacity * Constants.pulseOpacity)),
                style: style
            )
            context.stroke(
                rightTrail.trimmedPath(from: 0, to: revealedAmount),
                with: .color(.white.opacity(opacity * Constants.pulseOpacity)),
                style: style
            )
        }
        .frame(width: size.width, height: size.height)
        .blur(radius: Constants.pulseBlur)
        .blendMode(.screen)
    }

    private func particles(size: CGSize) -> some View {
        ZStack {
            ForEach(Array(Constants.particles.enumerated()), id: \.offset) { index, particle in
                Circle()
                    .fill(.white.opacity(particle.opacity * particleOpacity(for: index)))
                    .frame(width: particle.diameter, height: particle.diameter)
                    .blur(radius: particle.blur)
                    .position(
                        x: size.width * particle.horizontal + horizontalDrift(for: index),
                        y: size.height * particle.vertical - CGFloat(ambientProgress) * particle.travel
                    )
            }
        }
        .opacity(isLightPresented ? 1 : 0)
        .blendMode(.screen)
    }

    private func particleOpacity(for index: Int) -> Double {
        let delay = Double(index % Constants.particleDelayGroups) * Constants.particleDelayStep
        let localProgress = max(0, min(1, (ambientProgress - delay) / (1 - delay)))
        return sin(localProgress * .pi)
    }

    private func horizontalDrift(for index: Int) -> CGFloat {
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        return direction * CGFloat(ambientProgress) * Constants.particleHorizontalTravel
    }
}

private extension OnboardingHeroAtmosphereView {
    struct Particle {
        let horizontal: CGFloat
        let vertical: CGFloat
        let diameter: CGFloat
        let travel: CGFloat
        let blur: CGFloat
        let opacity: Double
    }

    enum Constants {
        static let lightCoreOpacity = 0.18
        static let lightEdgeOpacity = 0.055
        static let lightRadiusFactor: CGFloat = 0.52
        static let lightHorizontalScale: CGFloat = 0.52
        static let lightVerticalScale: CGFloat = 1.45
        static let lightRotation = -8.0
        static let lightX: CGFloat = 0.55
        static let lightY: CGFloat = 0.42
        static let initialLightScale: CGFloat = 0.16
        static let pulseRevealMultiplier = 1.9
        static let pulseFadeMultiplier = 1.3
        static let pulseOpacity = 0.3
        static let pulseLineWidth: CGFloat = 1.2
        static let pulseBlur: CGFloat = 1.8
        static let particleDelayGroups = 4
        static let particleDelayStep = 0.08
        static let particleHorizontalTravel: CGFloat = 7
        static let particles = [
            Particle(horizontal: 0.18, vertical: 0.68, diameter: 1.4, travel: 18, blur: 0.2, opacity: 0.5),
            Particle(horizontal: 0.28, vertical: 0.57, diameter: 2.1, travel: 25, blur: 0.6, opacity: 0.46),
            Particle(horizontal: 0.39, vertical: 0.74, diameter: 1.2, travel: 16, blur: 0.1, opacity: 0.62),
            Particle(horizontal: 0.48, vertical: 0.51, diameter: 1.7, travel: 22, blur: 0.4, opacity: 0.52),
            Particle(horizontal: 0.57, vertical: 0.64, diameter: 2.4, travel: 28, blur: 0.8, opacity: 0.38),
            Particle(horizontal: 0.66, vertical: 0.46, diameter: 1.1, travel: 15, blur: 0.1, opacity: 0.58),
            Particle(horizontal: 0.76, vertical: 0.7, diameter: 1.8, travel: 24, blur: 0.5, opacity: 0.44),
            Particle(horizontal: 0.84, vertical: 0.58, diameter: 1.3, travel: 19, blur: 0.2, opacity: 0.54),
            Particle(horizontal: 0.23, vertical: 0.43, diameter: 1.1, travel: 14, blur: 0.1, opacity: 0.48),
            Particle(horizontal: 0.72, vertical: 0.39, diameter: 1.5, travel: 20, blur: 0.3, opacity: 0.42)
        ]
    }
}
