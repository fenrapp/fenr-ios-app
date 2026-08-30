public struct LoadVehicleMotionCalibrationUseCase: Sendable {
    private let repository: any VehicleMotionCalibrationRepository

    public init(repository: any VehicleMotionCalibrationRepository) {
        self.repository = repository
    }

    public func execute(vin: String) async -> VehicleMotionCalibration? {
        await repository.load(vin: vin)
    }
}

public struct SaveVehicleMotionCalibrationUseCase: Sendable {
    private let repository: any VehicleMotionCalibrationRepository

    public init(repository: any VehicleMotionCalibrationRepository) {
        self.repository = repository
    }

    public func execute(_ calibration: VehicleMotionCalibration) async {
        await repository.save(calibration)
    }
}
