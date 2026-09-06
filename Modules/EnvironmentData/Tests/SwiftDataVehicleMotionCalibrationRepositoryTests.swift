@testable import EnvironmentData
import EnvironmentDomain
import Foundation
import Testing

@Suite("SwiftData bike IMU attitude repository")
struct SwiftDataVehicleMotionCalibrationRepositoryTests {
    @Test("Persists complete calibrations independently per VIN and updates in place")
    func persistsPerVIN() async throws {
        let repository = try VehicleMotionCalibrationRepositoryFactory.make(
            mapper: VehicleMotionCalibrationRecordMapper(),
            isStoredInMemoryOnly: true
        )
        let first = calibration(
            vin: Constants.firstVIN,
            values: .init(
                biasXRaw: 12,
                biasYRaw: -4,
                biasZRaw: 7,
                rollOffset: -2.5,
                pitchOffset: 1.25,
                profileVersion: 1,
                date: Date(timeIntervalSince1970: 100)
            )
        )
        let second = calibration(
            vin: Constants.secondVIN,
            values: .init(
                biasXRaw: -8,
                biasYRaw: 3,
                biasZRaw: 2,
                rollOffset: 4,
                pitchOffset: -6,
                profileVersion: 2,
                date: Date(timeIntervalSince1970: 200)
            )
        )

        await repository.save(first)
        await repository.save(second)

        #expect(await repository.load(vin: Constants.firstVIN) == first)
        #expect(await repository.load(vin: Constants.secondVIN) == second)
        #expect(await repository.load(vin: Constants.unknownVIN) == nil)

        let updatedFirst = calibration(
            vin: Constants.firstVIN,
            values: .init(
                biasXRaw: 14,
                biasYRaw: -5,
                biasZRaw: 8,
                rollOffset: -1,
                pitchOffset: 0.5,
                profileVersion: 3,
                date: Date(timeIntervalSince1970: 300)
            )
        )
        await repository.save(updatedFirst)

        #expect(await repository.load(vin: Constants.firstVIN) == updatedFirst)
        #expect(await repository.load(vin: Constants.secondVIN) == second)
    }
}

private extension SwiftDataVehicleMotionCalibrationRepositoryTests {
    func calibration(
        vin: String,
        values: CalibrationValues
    ) -> VehicleMotionCalibration {
        .init(
            vin: vin,
            gyroscopeBiasXRaw: values.biasXRaw,
            gyroscopeBiasYRaw: values.biasYRaw,
            gyroscopeBiasZRaw: values.biasZRaw,
            rollZeroOffsetDegrees: values.rollOffset,
            pitchZeroOffsetDegrees: values.pitchOffset,
            profileVersion: values.profileVersion,
            calibratedAt: values.date
        )
    }

    struct CalibrationValues {
        let biasXRaw: Double
        let biasYRaw: Double
        let biasZRaw: Double
        let rollOffset: Double
        let pitchOffset: Double
        let profileVersion: Int
        let date: Date
    }

    enum Constants {
        static let firstVIN = "FENRIMUTEST000001"
        static let secondVIN = "FENRIMUTEST000002"
        static let unknownVIN = "FENRIMUTESTUNKNOWN"
    }
}
