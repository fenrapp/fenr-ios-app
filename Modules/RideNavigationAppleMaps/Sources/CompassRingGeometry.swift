import CoreGraphics
import Foundation

struct CompassRingGeometry {
    struct Label {
        let center: CGPoint
        let angle: Double
        let gapHalfAngle: Double
    }

    let center: CGPoint
    let radius: CGFloat
    let labels: [Label]

    init(center: CGPoint, radius: CGFloat, headingDegrees: Double, labelSizes: [CGSize], padding: CGFloat) {
        self.center = center
        self.radius = radius
        let heading = headingDegrees.truncatingRemainder(dividingBy: Constants.fullTurnDegrees)
        labels = NavigationCardinal.allCases.enumerated().map { index, cardinal in
            let angle = (cardinal.bearingDegrees - heading) * .pi / Constants.halfTurnDegrees - .pi / 2
            let size = labelSizes[index]
            // A circle enclosing the glyph bounds guarantees clearance at diagonal headings too.
            let clearance = hypot(size.width, size.height) / 2 + padding
            return Label(
                center: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius),
                angle: angle,
                gapHalfAngle: asin(min(clearance / radius, 1))
            )
        }
    }

    var path: CGPath {
        let path = CGMutablePath()
        for index in labels.indices {
            let label = labels[index]
            let next = labels[(index + 1) % labels.count]
            let start = label.angle + label.gapHalfAngle
            let end = next.angle - next.gapHalfAngle + (index == labels.count - 1 ? 2 * .pi : 0)
            guard end > start else { continue }
            path.move(to: CGPoint(x: center.x + cos(start) * radius, y: center.y + sin(start) * radius))
            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        }
        return path
    }

    private enum Constants {
        static let fullTurnDegrees = 360.0
        static let halfTurnDegrees = 180.0
    }
}
