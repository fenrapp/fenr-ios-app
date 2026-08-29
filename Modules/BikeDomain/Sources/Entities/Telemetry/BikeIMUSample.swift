import Foundation

// Conventional Cartesian axis names keep raw IMU math readable.
// swiftlint:disable identifier_name
public struct BikeIMUVector: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}
// swiftlint:enable identifier_name

public struct BikeIMUSample: Equatable, Sendable {
    public let accelerationRaw: BikeIMUVector
    public let gyroscopeRaw: BikeIMUVector
    public let observedAt: Date

    public init(
        accelerationRaw: BikeIMUVector,
        gyroscopeRaw: BikeIMUVector,
        observedAt: Date
    ) {
        self.accelerationRaw = accelerationRaw
        self.gyroscopeRaw = gyroscopeRaw
        self.observedAt = observedAt
    }
}
