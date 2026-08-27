public protocol VehicleMotionCalibrationRepository: Sendable {
    func load(vin: String) async -> VehicleMotionCalibration?
    func save(_ calibration: VehicleMotionCalibration) async
}
