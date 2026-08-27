import Foundation

public struct MotionQuaternion: Codable, Equatable, Sendable {
    public let xComponent: Double
    public let yComponent: Double
    public let zComponent: Double
    public let scalarComponent: Double

    public init(xComponent: Double, yComponent: Double, zComponent: Double, scalarComponent: Double) {
        self.xComponent = xComponent
        self.yComponent = yComponent
        self.zComponent = zComponent
        self.scalarComponent = scalarComponent
    }

    public var isFinite: Bool {
        xComponent.isFinite && yComponent.isFinite && zComponent.isFinite && scalarComponent.isFinite
    }
}

public enum MotionAccuracy: Int, Codable, Equatable, Sendable {
    case unavailable
    case unreliable
    case low
    case medium
    case high
}

public struct DeviceMotionSample: Equatable, Sendable {
    public let attitude: MotionQuaternion
    public let magneticHeadingDegrees: Double?
    public let magneticAccuracy: MotionAccuracy
    public let observedAt: Date

    public init(
        attitude: MotionQuaternion,
        magneticHeadingDegrees: Double? = nil,
        magneticAccuracy: MotionAccuracy = .unavailable,
        observedAt: Date
    ) {
        self.attitude = attitude
        self.magneticHeadingDegrees = magneticHeadingDegrees
        self.magneticAccuracy = magneticAccuracy
        self.observedAt = observedAt
    }

    public var isFinite: Bool {
        attitude.isFinite
            && (magneticHeadingDegrees?.isFinite ?? true)
    }
}
