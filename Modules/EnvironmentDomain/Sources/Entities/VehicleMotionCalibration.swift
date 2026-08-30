import Foundation

public struct VehicleMotionCalibration: Equatable, Sendable {
    public let vin: String
    public let gyroscopeBiasXRaw: Double
    public let gyroscopeBiasYRaw: Double
    public let gyroscopeBiasZRaw: Double
    public let rollZeroOffsetDegrees: Double
    public let pitchZeroOffsetDegrees: Double
    public let profileVersion: Int
    public let calibratedAt: Date

    public init(
        vin: String,
        gyroscopeBiasXRaw: Double,
        gyroscopeBiasYRaw: Double,
        gyroscopeBiasZRaw: Double,
        rollZeroOffsetDegrees: Double = .zero,
        pitchZeroOffsetDegrees: Double = .zero,
        profileVersion: Int,
        calibratedAt: Date
    ) {
        self.vin = vin
        self.gyroscopeBiasXRaw = gyroscopeBiasXRaw
        self.gyroscopeBiasYRaw = gyroscopeBiasYRaw
        self.gyroscopeBiasZRaw = gyroscopeBiasZRaw
        self.rollZeroOffsetDegrees = rollZeroOffsetDegrees
        self.pitchZeroOffsetDegrees = pitchZeroOffsetDegrees
        self.profileVersion = profileVersion
        self.calibratedAt = calibratedAt
    }
}
