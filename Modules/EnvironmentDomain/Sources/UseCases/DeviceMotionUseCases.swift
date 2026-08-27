public struct ObserveDeviceMotionUseCase: Sendable {
    private let repository: any DeviceMotionRepository

    public init(repository: any DeviceMotionRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<DeviceMotionSample> {
        await repository.observeDeviceMotion()
    }
}

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
