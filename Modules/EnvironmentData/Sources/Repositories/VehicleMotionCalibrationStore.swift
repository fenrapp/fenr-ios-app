import EnvironmentDomain
import Foundation
import SwiftData

@ModelActor
actor VehicleMotionCalibrationStore {
    func load(vin: String, mapper: VehicleMotionCalibrationRecordMapper) -> VehicleMotionCalibration? {
        do {
            return try fetch(vin: vin).map(mapper.mapToDomain)
        } catch {
            return nil
        }
    }

    func save(_ calibration: VehicleMotionCalibration, mapper: VehicleMotionCalibrationRecordMapper) {
        do {
            if let record = try fetch(vin: calibration.vin) {
                mapper.update(record, from: calibration)
            } else {
                modelContext.insert(mapper.makeRecord(from: calibration))
            }
            try modelContext.save()
        } catch {
        }
    }

    private func fetch(vin: String) throws -> VehicleMotionCalibrationRecord? {
        var descriptor = FetchDescriptor<VehicleMotionCalibrationRecord>(
            predicate: #Predicate { $0.vin == vin }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

}
