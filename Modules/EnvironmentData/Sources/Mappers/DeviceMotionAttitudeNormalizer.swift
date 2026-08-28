import EnvironmentDomain

public struct DeviceMotionAttitudeNormalizer: Sendable {
    public init() {}

    public func normalize(
        _ attitude: MotionQuaternion,
        orientation: DeviceLandscapeOrientation
    ) -> MotionQuaternion {
        guard orientation == .right else { return attitude }
        return attitude.multiplied(by: Constants.halfTurnAroundScreenNormal)
    }
}

private extension MotionQuaternion {
    func multiplied(by other: Self) -> Self {
        .init(
            xComponent: scalarComponent * other.xComponent + xComponent * other.scalarComponent
                + yComponent * other.zComponent - zComponent * other.yComponent,
            yComponent: scalarComponent * other.yComponent - xComponent * other.zComponent
                + yComponent * other.scalarComponent + zComponent * other.xComponent,
            zComponent: scalarComponent * other.zComponent + xComponent * other.yComponent
                - yComponent * other.xComponent + zComponent * other.scalarComponent,
            scalarComponent: scalarComponent * other.scalarComponent - xComponent * other.xComponent
                - yComponent * other.yComponent - zComponent * other.zComponent
        )
    }
}

private enum Constants {
    static let halfTurnAroundScreenNormal = MotionQuaternion(
        xComponent: .zero,
        yComponent: .zero,
        zComponent: 1,
        scalarComponent: .zero
    )
}
