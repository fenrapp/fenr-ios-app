import Foundation
import SwiftData

public enum VehicleMotionCalibrationRepositoryFactory {
    public static func make(
        mapper: VehicleMotionCalibrationRecordMapper,
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws -> SwiftDataVehicleMotionCalibrationRepository {
        let configuration = storeURL.map { ModelConfiguration(Constants.storeName, url: $0) } ?? ModelConfiguration(
            Constants.storeName,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        let container = try ModelContainer(
            for: VehicleMotionCalibrationRecord.self,
            configurations: configuration
        )
        return SwiftDataVehicleMotionCalibrationRepository(
            store: VehicleMotionCalibrationStore(modelContainer: container),
            mapper: mapper
        )
    }

    private enum Constants {
        static let storeName = "BikeIMUAttitudeV1"
    }
}
