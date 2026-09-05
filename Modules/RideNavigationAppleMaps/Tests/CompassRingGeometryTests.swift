import CoreGraphics
import Foundation
@testable import RideNavigationAppleMaps
import Testing

@Suite("Compass ring geometry")
struct CompassRingGeometryTests {
    @Test(
        "Cardinals lie on the ring and arcs leave room for upright labels",
        arguments: [0, 45, 90, 180, 270, 359, 360]
    )
    func placesLabelsAndGaps(heading: Double) {
        let center = CGPoint(x: 52, y: 52)
        let geometry = CompassRingGeometry(
            center: center, radius: 38, headingDegrees: heading,
            labelSizes: Array(repeating: CGSize(width: 10, height: 12), count: 4), padding: 2
        )
        #expect(geometry.labels.count == 4)
        for label in geometry.labels {
            #expect(abs(hypot(label.center.x - center.x, label.center.y - center.y) - 38) < 0.001)
            #expect(label.gapHalfAngle > 0)
        }
        var arcs = 0
        geometry.path.applyWithBlock { element in
            if element.pointee.type == .moveToPoint { arcs += 1 }
        }
        #expect(arcs == 4)
        #expect(!geometry.path.isEmpty)
    }

    @Test("North crosses zero without a positional jump and wider labels receive larger gaps")
    func wrapsAndMeasures() {
        let before = CompassRingTestFactory.make(359).labels[0].center
        let after = CompassRingTestFactory.make(0).labels[0].center
        #expect(hypot(before.x - after.x, before.y - after.y) < 1)
        #expect(abs(after.x) < 0.001)
        #expect(after.y == -38)
        #expect(CompassRingTestFactory.make(360).labels[0].center == after)
        let wide = CompassRingTestFactory.make(45, width: 20)
        let narrow = CompassRingTestFactory.make(45)
        #expect(wide.labels[0].gapHalfAngle > narrow.labels[0].gapHalfAngle)
    }
}
