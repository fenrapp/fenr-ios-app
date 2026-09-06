import EnvironmentDomain
import Foundation

public struct SwiftDataVehicleMotionCalibrationRepository: VehicleMotionCalibrationRepository, Sendable {
    private let store: VehicleMotionCalibrationStore
    private let mapper: VehicleMotionCalibrationRecordMapper

    init(
        store: VehicleMotionCalibrationStore,
        mapper: VehicleMotionCalibrationRecordMapper
    ) {
        self.store = store
        self.mapper = mapper
    }

    public func load(vin: String) async -> VehicleMotionCalibration? {
        await store.load(vin: vin, mapper: mapper)
    }

    public func save(_ calibration: VehicleMotionCalibration) async {
        await store.save(calibration, mapper: mapper)
    }
}
