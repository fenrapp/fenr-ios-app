import EnvironmentDomain
import Foundation

public actor DebugVehicleMotionCalibrationRepository: VehicleMotionCalibrationRepository {
    private var calibrations: [String: VehicleMotionCalibration]

    public init(calibrations: [String: VehicleMotionCalibration] = [:]) {
        self.calibrations = calibrations
    }

    public func load(vin: String) -> VehicleMotionCalibration? {
        calibrations[vin] ?? VehicleMotionCalibration(
            vin: vin,
            referenceAttitude: .init(
                xComponent: .zero,
                yComponent: .zero,
                zComponent: .zero,
                scalarComponent: 1
            ),
            calibratedAt: Date()
        )
    }

    public func save(_ calibration: VehicleMotionCalibration) {
        calibrations[calibration.vin] = calibration
    }
}
