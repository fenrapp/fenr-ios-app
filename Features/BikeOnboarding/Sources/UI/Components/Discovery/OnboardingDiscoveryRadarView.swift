import SwiftUI

struct OnboardingDiscoveryRadarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isScanning: Bool

    var body: some View {
        Group {
            if reduceMotion || !isScanning {
                radar(phase: .zero)
            } else {
                TimelineView(.animation(minimumInterval: Constants.frameInterval)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: Constants.cycleDuration)
                    radar(phase: phase)
                }
            }
        }
        .frame(height: Constants.height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func radar(phase: TimeInterval) -> some View {
        ZStack {
            if isScanning, !reduceMotion {
                radioWave(phase: phase, delay: .zero)
                radioWave(phase: phase, delay: Constants.waveDelay)
            }

            Circle()
                .fill(Color.primary.opacity(Constants.symbolBackgroundOpacity))
                .frame(width: Constants.symbolBackgroundSize, height: Constants.symbolBackgroundSize)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: Constants.symbolSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
        }
    }

    private func radioWave(phase: TimeInterval, delay: TimeInterval) -> some View {
        let progress = waveProgress(phase: phase, delay: delay)
        let isPending = phase < delay
        return Circle()
            .stroke(
                Color.primary.opacity(isPending ? .zero : Constants.waveOpacity * (1 - progress)),
                lineWidth: Constants.waveWidth
            )
            .frame(width: Constants.waveSize, height: Constants.waveSize)
            .scaleEffect(Constants.waveStartScale + Constants.waveScaleRange * progress)
    }

    private func waveProgress(phase: TimeInterval, delay: TimeInterval) -> Double {
        let elapsed = phase - delay
        guard elapsed > .zero else { return .zero }
        return min(elapsed / Constants.waveDuration, 1)
    }
}

private extension OnboardingDiscoveryRadarView {
    enum Constants {
        static let height: CGFloat = 164
        static let frameInterval = 1 / 30.0
        static let cycleDuration = 1.8
        static let waveDuration = 0.9
        static let waveDelay = 0.15
        static let waveOpacity = 0.2
        static let waveWidth: CGFloat = 1
        static let waveSize: CGFloat = 104
        static let waveStartScale = 0.56
        static let waveScaleRange = 0.82
        static let symbolBackgroundOpacity = 0.08
        static let symbolBackgroundSize: CGFloat = 72
        static let symbolSize: CGFloat = 29
    }
}
