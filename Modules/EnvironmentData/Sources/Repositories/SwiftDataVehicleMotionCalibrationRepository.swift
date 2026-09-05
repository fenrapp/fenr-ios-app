import EnvironmentDomain
import Foundation
import SwiftData

public final class SwiftDataVehicleMotionCalibrationRepository: VehicleMotionCalibrationRepository, Sendable {
    private let store: VehicleMotionCalibrationStore
    private let mapper: VehicleMotionCalibrationRecordMapper

    public convenience init(
        mapper: VehicleMotionCalibrationRecordMapper,
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws {
        let configuration = storeURL.map { ModelConfiguration(Constants.storeName, url: $0) } ?? ModelConfiguration(
            Constants.storeName,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        let container = try ModelContainer(
            for: VehicleMotionCalibrationRecord.self,
            configurations: configuration
        )
        self.init(modelContainer: container, mapper: mapper)
    }

    public init(
        modelContainer: ModelContainer,
        mapper: VehicleMotionCalibrationRecordMapper
    ) {
        store = VehicleMotionCalibrationStore(modelContainer: modelContainer)
        self.mapper = mapper
    }

    public func load(vin: String) async -> VehicleMotionCalibration? {
        await store.load(vin: vin, mapper: mapper)
    }

    public func save(_ calibration: VehicleMotionCalibration) async {
        await store.save(calibration, mapper: mapper)
    }

    private enum Constants {
        static let storeName = "BikeIMUAttitudeV1"
    }
}
