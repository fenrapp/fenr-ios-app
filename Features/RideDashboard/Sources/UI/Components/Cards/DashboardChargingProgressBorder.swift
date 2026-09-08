import SwiftUI

struct DashboardChargingProgressBorder: View {
    @Environment(\.self) private var environment
    @State private var balancingPulse = false

    let progress: Double?
    let cornerRadius: CGFloat
    let isBalancing: Bool

    var body: some View {
        let palette = DashboardChargingBorderPalette.resolve(in: environment)
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size)
                .insetBy(
                    dx: DashboardChargingBorderCanvas.renderingOutset,
                    dy: DashboardChargingBorderCanvas.renderingOutset
                )
            let path = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
            ZStack {
                path.stroke(palette.border, lineWidth: Constants.borderWidth)
                if isBalancing, progress != nil {
                    DashboardChargingBorderPulse(
                        path: path, progress: clampedProgress, isExpanded: balancingPulse, palette: palette
                    )
                }
                DashboardChargingBorderCanvas(
                    progress: clampedProgress,
                    balancing: isBalancing ? 1 : .zero,
                    visibility: progress == nil ? .zero : 1,
                    path: path,
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    palette: palette
                )
            }
        }
        .padding(-DashboardChargingBorderCanvas.renderingOutset)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Constants.progressAnimationDuration),
            value: clampedProgress
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Constants.stateAnimationDuration),
            value: isBalancing
        )
        .onAppear(perform: updateBalancingPulse)
        .onChange(of: isBalancing) { updateBalancingPulse() }
        .onChange(of: reduceMotion) { updateBalancingPulse() }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var reduceMotion: Bool { environment.accessibilityReduceMotion }

    private var clampedProgress: Double {
        min(max(progress ?? .zero, .zero), 1)
    }

    private func updateBalancingPulse() {
        guard isBalancing, !reduceMotion else {
            balancingPulse = false
            return
        }

        balancingPulse = false
        withAnimation(
            .easeInOut(duration: Constants.balancingPulseDuration)
                .repeatForever(autoreverses: true)
        ) {
            balancingPulse = true
        }
    }

    private enum Constants {
        static let borderWidth: CGFloat = 1
        static let progressAnimationDuration = 0.45
        static let stateAnimationDuration = 0.3
        static let balancingPulseDuration = 1.15
    }
}
