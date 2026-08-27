import Foundation

public struct VehicleMotionCalibration: Codable, Equatable, Sendable {
    public let vin: String
    public let referenceAttitude: MotionQuaternion
    public let calibratedAt: Date

    public init(vin: String, referenceAttitude: MotionQuaternion, calibratedAt: Date) {
        self.vin = vin
        self.referenceAttitude = referenceAttitude
        self.calibratedAt = calibratedAt
    }
}
