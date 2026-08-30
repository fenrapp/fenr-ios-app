import BikeDomain

enum BikeChargePowerControlEvent: Equatable, Sendable {
    case prepare(BikeChargingStatus)
    case setPowerLimit(Int)
    case setTarget(Int)
}

actor RecordingBikeChargePowerControlRepository: BikeChargePowerControlRepository {
    private var recordedEvents: [BikeChargePowerControlEvent] = []
    private var currentError: BikeChargePowerControlTestError?

    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        try record(.prepare(chargingStatus))
        return snapshot(
            watts: Int(chargingStatus.maximumPowerWatts),
            target: chargingStatus.maximumStateOfChargePercent
        )
    }

    func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        try record(.setPowerLimit(watts))
        return snapshot(watts: watts, target: 100)
    }

    func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        try record(.setTarget(percent))
        return snapshot(watts: 1_000, target: percent)
    }

    func events() -> [BikeChargePowerControlEvent] {
        recordedEvents
    }

    func setError(_ error: BikeChargePowerControlTestError) {
        currentError = error
    }

    private func record(_ event: BikeChargePowerControlEvent) throws {
        if let currentError { throw currentError }
        recordedEvents.append(event)
    }

    private func snapshot(watts: Int, target: Int) -> BikeChargePowerControlSnapshot {
        .init(
            vcuFirmware: "1.12.0",
            isFirmwareCompatible: true,
            readRequestHex: "read",
            readResponseHex: "response",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 20,
                chargePowerWatts: watts,
                maximumStateOfChargeDeciPercent: target * 10,
                standardChargerMaximumPowerWatts: 3_300,
                backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: "write",
            didPassNoOpWrite: true,
            logLines: []
        )
    }
}

struct DefaultBikeChargePowerControlRepository: BikeChargePowerControlRepository {}

enum BikeChargePowerControlTestError: Error, Equatable {
    case expected
}
