import SwiftUI

nonisolated struct DashboardChargingBorderCanvas: View, Animatable {
    var progress: Double
    var balancing: Double
    var visibility: Double
    let path: Path
    let center: CGPoint
    let palette: DashboardChargingBorderPalette

    static let renderingOutset: CGFloat = 40

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { .init(progress, .init(balancing, visibility)) }
        set {
            progress = newValue.first
            balancing = newValue.second.first
            visibility = newValue.second.second
        }
    }

    var body: some View {
        Canvas { context, _ in
            guard visibility > .zero, progress > .zero else { return }

            let colors = palette.colors(at: balancing)
            let start = Color(colors.start)
            let head = Color(colors.head)
            let glow = Color(colors.glow)
            let gradient = GraphicsContext.Shading.conicGradient(
                Gradient(colors: [start, Color(colors.middle), start]), center: center
            )
            let segment = path.trimmedPath(from: .zero, to: progress)
            stroke(
                segment, shading: gradient,
                appearance: StrokeAppearance(
                    width: Constants.progressBorderWidth, glow: glow.opacity(palette.progressGlowOpacity),
                    radius: Constants.progressGlowRadius, opacity: visibility
                ),
                context: context
            )
            stroke(
                path.trimmedPath(from: max(progress - Constants.progressHeadLength, .zero), to: progress),
                shading: .color(head),
                appearance: StrokeAppearance(
                    width: Constants.progressHeadWidth, glow: head.opacity(Constants.progressHeadGlowOpacity),
                    radius: Constants.progressHeadGlowRadius, opacity: visibility
                ),
                context: context
            )
        }
    }

    private func stroke(
        _ path: Path,
        shading: GraphicsContext.Shading,
        appearance: StrokeAppearance,
        context: GraphicsContext
    ) {
        var layer = context
        layer.opacity = appearance.opacity
        layer.addFilter(.shadow(color: appearance.glow, radius: appearance.radius))
        layer.stroke(
            path, with: shading,
            style: StrokeStyle(lineWidth: appearance.width, lineCap: .round, lineJoin: .round)
        )
    }

    private struct StrokeAppearance {
        let width: CGFloat
        let glow: Color
        let radius: CGFloat
        let opacity: Double
    }

    private enum Constants {
        static let progressBorderWidth: CGFloat = 3
        static let progressGlowRadius: CGFloat = 6
        static let progressHeadWidth: CGFloat = 3.5
        static let progressHeadLength = 0.018
        static let progressHeadGlowRadius: CGFloat = 8
        static let progressHeadGlowOpacity = 0.72
    }
}
