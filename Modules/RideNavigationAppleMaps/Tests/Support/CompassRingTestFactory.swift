import CoreGraphics
@testable import RideNavigationAppleMaps

enum CompassRingTestFactory {
    static func make(_ heading: Double, width: CGFloat = 10) -> CompassRingGeometry {
        .init(
            center: .zero, radius: 38, headingDegrees: heading,
            labelSizes: Array(repeating: CGSize(width: width, height: 12), count: 4), padding: 2
        )
    }
}
