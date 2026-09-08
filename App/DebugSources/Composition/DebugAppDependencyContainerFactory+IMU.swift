import VehicleSession

extension DebugAppDependencyContainerFactory {
    static func makeIMUProfile() -> BikeIMUProfile {
        .init(
            version: 1,
            accelerationTransform: .init(bikeX: .positiveX, bikeY: .positiveY, bikeZ: .positiveZ),
            gyroscopeTransform: .init(bikeX: .positiveX, bikeY: .positiveY, bikeZ: .positiveZ),
            gyroscopeDegreesPerSecondPerRawUnit: .init(x: 1, y: 1, z: 1),
            oneGRaw: 1_000
        )
    }
}
