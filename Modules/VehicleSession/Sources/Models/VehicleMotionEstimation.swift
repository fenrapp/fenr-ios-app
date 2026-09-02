import EnvironmentDomain

public struct VehicleMotionEstimation: Equatable, Sendable {
    public let snapshot: VehicleMotionSnapshot
    public let calibrationToPersist: VehicleMotionCalibration?

    public init(
        snapshot: VehicleMotionSnapshot,
        calibrationToPersist: VehicleMotionCalibration? = nil
    ) {
        self.snapshot = snapshot
        self.calibrationToPersist = calibrationToPersist
    }
}
