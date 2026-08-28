import EnvironmentData
import EnvironmentDomain
import Testing

@Suite("Device motion attitude normalization")
struct DeviceMotionAttitudeNormalizerTests {
    @Test("Both landscape orientations normalize to the same canonical attitude")
    func normalizesBothLandscapeOrientations() {
        let normalizer = DeviceMotionAttitudeNormalizer()
        let identity = MotionQuaternion(
            xComponent: .zero,
            yComponent: .zero,
            zComponent: .zero,
            scalarComponent: 1
        )
        let landscapeRightIdentity = MotionQuaternion(
            xComponent: .zero,
            yComponent: .zero,
            zComponent: -1,
            scalarComponent: .zero
        )

        #expect(normalizer.normalize(identity, orientation: .left) == identity)
        #expect(normalizer.normalize(landscapeRightIdentity, orientation: .right) == identity)
    }
}
