import Foundation
import SwiftData

@Model
final class VehicleMotionCalibrationRecord {
    @Attribute(.unique) var vin: String
    var gyroscopeBiasXRaw: Double
    var gyroscopeBiasYRaw: Double
    var gyroscopeBiasZRaw: Double
    var rollZeroOffsetDegrees: Double
    var pitchZeroOffsetDegrees: Double
    var profileVersion: Int
    var calibratedAt: Date

    init(vin: String, calibratedAt: Date) {
        self.vin = vin
        gyroscopeBiasXRaw = .zero
        gyroscopeBiasYRaw = .zero
        gyroscopeBiasZRaw = .zero
        rollZeroOffsetDegrees = .zero
        pitchZeroOffsetDegrees = .zero
        profileVersion = 1
        self.calibratedAt = calibratedAt
    }
}
