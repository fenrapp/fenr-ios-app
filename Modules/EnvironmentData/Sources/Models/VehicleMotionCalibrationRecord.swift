import Foundation
import SwiftData

@Model
final class VehicleMotionCalibrationRecord {
    @Attribute(.unique) var vin: String
    var quaternionX: Double
    var quaternionY: Double
    var quaternionZ: Double
    var quaternionW: Double
    var calibratedAt: Date

    init(vin: String, calibratedAt: Date) {
        self.vin = vin
        quaternionX = .zero
        quaternionY = .zero
        quaternionZ = .zero
        quaternionW = 1
        self.calibratedAt = calibratedAt
    }
}
