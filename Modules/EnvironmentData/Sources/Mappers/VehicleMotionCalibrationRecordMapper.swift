import EnvironmentDomain

public struct VehicleMotionCalibrationRecordMapper: Sendable {
    public init() {}

    func makeRecord(from calibration: VehicleMotionCalibration) -> VehicleMotionCalibrationRecord {
        let record = VehicleMotionCalibrationRecord(
            vin: calibration.vin,
            calibratedAt: calibration.calibratedAt
        )
        update(record, from: calibration)
        return record
    }

    func update(_ record: VehicleMotionCalibrationRecord, from calibration: VehicleMotionCalibration) {
        record.vin = calibration.vin
        record.quaternionX = calibration.referenceAttitude.xComponent
        record.quaternionY = calibration.referenceAttitude.yComponent
        record.quaternionZ = calibration.referenceAttitude.zComponent
        record.quaternionW = calibration.referenceAttitude.scalarComponent
        record.calibratedAt = calibration.calibratedAt
    }

    func mapToDomain(_ record: VehicleMotionCalibrationRecord) -> VehicleMotionCalibration {
        VehicleMotionCalibration(
            vin: record.vin,
            referenceAttitude: .init(
                xComponent: record.quaternionX,
                yComponent: record.quaternionY,
                zComponent: record.quaternionZ,
                scalarComponent: record.quaternionW
            ),
            calibratedAt: record.calibratedAt
        )
    }
}
