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
        record.gyroscopeBiasXRaw = calibration.gyroscopeBiasXRaw
        record.gyroscopeBiasYRaw = calibration.gyroscopeBiasYRaw
        record.gyroscopeBiasZRaw = calibration.gyroscopeBiasZRaw
        record.rollZeroOffsetDegrees = calibration.rollZeroOffsetDegrees
        record.pitchZeroOffsetDegrees = calibration.pitchZeroOffsetDegrees
        record.profileVersion = calibration.profileVersion
        record.calibratedAt = calibration.calibratedAt
    }

    func mapToDomain(_ record: VehicleMotionCalibrationRecord) -> VehicleMotionCalibration {
        VehicleMotionCalibration(
            vin: record.vin,
            gyroscopeBiasXRaw: record.gyroscopeBiasXRaw,
            gyroscopeBiasYRaw: record.gyroscopeBiasYRaw,
            gyroscopeBiasZRaw: record.gyroscopeBiasZRaw,
            rollZeroOffsetDegrees: record.rollZeroOffsetDegrees,
            pitchZeroOffsetDegrees: record.pitchZeroOffsetDegrees,
            profileVersion: record.profileVersion,
            calibratedAt: record.calibratedAt
        )
    }
}
