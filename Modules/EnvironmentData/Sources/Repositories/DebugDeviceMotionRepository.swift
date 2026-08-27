import EnvironmentDomain
import Foundation
import RuntimeConfiguration

public actor DebugDeviceMotionRepository: DeviceMotionRepository {
    public init() {}

    public func observeDeviceMotion() -> AsyncStream<DeviceMotionSample> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                var tick = 0
                while !Task.isCancelled {
                    let lean = sin(Double(tick) * 0.16) * 24
                    let pitch = sin(Double(tick) * 0.09) * 11
                    continuation.yield(Self.sample(
                        leanDegrees: lean,
                        pitchDegrees: pitch,
                        headingDegrees: Double((tick * 3) % 360),
                        date: .now
                    ))
                    tick += 1
                    try? await Task.sleep(for: Constants.updateInterval)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

}

private extension DebugDeviceMotionRepository {
    static func sample(
        leanDegrees: Double,
        pitchDegrees: Double,
        headingDegrees: Double,
        date: Date
    ) -> DeviceMotionSample {
        let attitude = quaternion(
            xRadians: pitchDegrees * .pi / 180,
            zRadians: leanDegrees * .pi / 180
        )
        return DeviceMotionSample(
            attitude: attitude,
            magneticHeadingDegrees: headingDegrees,
            magneticAccuracy: .high,
            observedAt: date
        )
    }

    static func quaternion(xRadians: Double, zRadians: Double) -> MotionQuaternion {
        let xHalf = xRadians / 2
        let zHalf = zRadians / 2
        let pitchRotation = MotionQuaternion(
            xComponent: sin(xHalf),
            yComponent: .zero,
            zComponent: .zero,
            scalarComponent: cos(xHalf)
        )
        let rollRotation = MotionQuaternion(
            xComponent: .zero,
            yComponent: .zero,
            zComponent: sin(zHalf),
            scalarComponent: cos(zHalf)
        )
        return .init(
            xComponent: rollRotation.scalarComponent * pitchRotation.xComponent
                + rollRotation.xComponent * pitchRotation.scalarComponent
                + rollRotation.yComponent * pitchRotation.zComponent
                - rollRotation.zComponent * pitchRotation.yComponent,
            yComponent: rollRotation.scalarComponent * pitchRotation.yComponent
                - rollRotation.xComponent * pitchRotation.zComponent
                + rollRotation.yComponent * pitchRotation.scalarComponent
                + rollRotation.zComponent * pitchRotation.xComponent,
            zComponent: rollRotation.scalarComponent * pitchRotation.zComponent
                + rollRotation.xComponent * pitchRotation.yComponent
                - rollRotation.yComponent * pitchRotation.xComponent
                + rollRotation.zComponent * pitchRotation.scalarComponent,
            scalarComponent: rollRotation.scalarComponent * pitchRotation.scalarComponent
                - rollRotation.xComponent * pitchRotation.xComponent
                - rollRotation.yComponent * pitchRotation.yComponent
                - rollRotation.zComponent * pitchRotation.zComponent
        )
    }

    enum Constants {
        static let updateInterval = Duration.milliseconds(50)
    }
}
