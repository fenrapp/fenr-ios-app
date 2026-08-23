import DesignSystem
import SwiftUI

struct DashboardGaugeArc: View {
    let progress: Double
    let color: Color
    let showsTicks: Bool
    let targetProgress: Double?
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height)
            let radius = max(.zero, min((size.width / 2) - Constants.horizontalInset, size.height))
            let trackPath = arcPath(center: center, radius: radius)
            let outerPath = arcPath(center: center, radius: radius + Constants.outerRingOffset)

            context.stroke(
                outerPath,
                with: .color(DesignColor.primaryText.opacity(Constants.outerRingOpacity)),
                style: .init(lineWidth: Constants.outerRingLineWidth, lineCap: .round)
            )
            context.stroke(
                trackPath,
                with: .color(DesignColor.primaryText.opacity(Constants.trackOpacity)),
                style: .init(lineWidth: Constants.trackLineWidth, lineCap: .round)
            )
            if showsTicks {
                drawTickMarks(context: context, center: center, radius: radius)
            }
            drawProgressSegments(context: context, center: center, radius: radius)
            drawTargetZone(context: context, center: center, radius: radius)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: Constants.animationDuration), value: progress)
        .shadow(
            color: reduceMotion ? .clear : color.opacity(Constants.glowOpacity),
            radius: reduceMotion ? .zero : Constants.glowRadius
        )
    }

    private func arcPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(Constants.startAngleDegrees),
                endAngle: .degrees(Constants.endAngleDegrees),
                clockwise: false
            )
        }
    }

    private func drawTickMarks(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for index in 0 ... Constants.tickCount {
            let fraction = Double(index) / Double(Constants.tickCount)
            let angle = Double.pi * (Constants.startAngleDegrees
                + (Constants.endAngleDegrees - Constants.startAngleDegrees) * fraction) / 180
            let outerRadius = radius - Constants.tickOuterInset
            let outer = CGPoint(
                x: center.x + outerRadius * cos(angle),
                y: center.y + outerRadius * sin(angle)
            )
            let innerRadius = outerRadius - (index.isMultiple(of: Constants.majorTickInterval)
                ? Constants.majorTickLength : Constants.minorTickLength)
            let inner = CGPoint(
                x: center.x + innerRadius * cos(angle),
                y: center.y + innerRadius * sin(angle)
            )
            var tick = Path()
            tick.move(to: inner)
            tick.addLine(to: outer)
            context.stroke(
                tick,
                with: .color(DesignColor.primaryText.opacity(Constants.inactiveTickOpacity)),
                lineWidth: Constants.tickLineWidth
            )
        }
    }

    private func drawProgressSegments(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        guard progress > .zero else { return }
        let segmentCount = Int((Double(Constants.segmentCount) * progress).rounded(.up))
        for index in 0 ..< segmentCount {
            let start = Double(index) / Double(Constants.segmentCount)
            let end = min(Double(index + 1) / Double(Constants.segmentCount) - Constants.segmentGap, progress)
            guard end > start else { continue }
            let path = Path { path in
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: angle(for: start),
                    endAngle: angle(for: end),
                    clockwise: false
                )
            }
            context.stroke(
                path,
                with: .color(color),
                style: .init(lineWidth: Constants.progressLineWidth, lineCap: .butt)
            )
        }
    }

    private func drawTargetZone(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        guard let targetProgress else { return }
        let start = max(.zero, targetProgress - Constants.targetZoneLength)
        let targetZone = Path { path in
            path.addArc(
                center: center,
                radius: radius + Constants.targetZoneRadiusOffset,
                startAngle: angle(for: start),
                endAngle: angle(for: targetProgress),
                clockwise: false
            )
        }
        context.stroke(
            targetZone,
            with: .color(DesignColor.positive),
            style: .init(lineWidth: Constants.targetZoneLineWidth, lineCap: .round)
        )
    }

    private func angle(for progress: Double) -> Angle {
        .degrees(Constants.startAngleDegrees
            + (Constants.endAngleDegrees - Constants.startAngleDegrees) * progress)
    }

    private enum Constants {
        static let horizontalInset: CGFloat = 32
        static let startAngleDegrees = 180.0
        static let endAngleDegrees = 360.0
        static let outerRingOffset: CGFloat = 14
        static let outerRingLineWidth: CGFloat = 1.5
        static let outerRingOpacity = 0.3
        static let trackLineWidth: CGFloat = 7
        static let trackOpacity = 0.12
        static let progressLineWidth: CGFloat = 8
        static let tickLineWidth: CGFloat = 1
        static let tickOuterInset: CGFloat = 18
        static let tickCount = 40
        static let majorTickInterval = 6
        static let majorTickLength: CGFloat = 15
        static let minorTickLength: CGFloat = 8
        static let inactiveTickOpacity = 0.14
        static let segmentCount = 24
        static let segmentGap = 0.008
        static let targetZoneLength = 0.12
        static let targetZoneRadiusOffset: CGFloat = 14
        static let targetZoneLineWidth: CGFloat = 5
        static let glowOpacity = 0.42
        static let glowRadius: CGFloat = 14
        static let animationDuration = 0.22
    }
}
