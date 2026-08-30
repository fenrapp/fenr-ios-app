import BikeDomain

actor ChargeControlRepository: BikeChargePowerControlRepository {
    private var prepareCalls = 0
    private var powerWrites: [Int] = []
    private var targetWrites: [Int] = []
    private var activeWrites = 0
    private var highestConcurrentWriteCount = 0
    private var powerWritesAreSuspended = false
    private var powerWritesFail = false
    private var powerWriteWaiters: [CheckedContinuation<Void, Never>] = []
    private var currentPowerWatts = 1_000
    private var currentTargetPercent = 100
    private let passesNoOpWrite: Bool
    private let preparationDelay: Duration?
    private var cancelledPreparations = 0

    init(
        passesNoOpWrite: Bool = true,
        preparationDelay: Duration? = nil
    ) {
        self.passesNoOpWrite = passesNoOpWrite
        self.preparationDelay = preparationDelay
    }

    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        prepareCalls += 1
        if let preparationDelay {
            do {
                try await Task.sleep(for: preparationDelay)
            } catch is CancellationError {
                cancelledPreparations += 1
                throw CancellationError()
            }
        }
        currentPowerWatts = Int(chargingStatus.maximumPowerWatts.rounded())
        currentTargetPercent = chargingStatus.maximumStateOfChargePercent
        return snapshot(
            watts: currentPowerWatts,
            target: currentTargetPercent
        )
    }

    func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        beginWrite()
        defer { finishWrite() }
        powerWrites.append(watts)
        if powerWritesFail {
            throw ChargeControlRepositoryError.writeRejected
        }
        if powerWritesAreSuspended {
            await withCheckedContinuation { powerWriteWaiters.append($0) }
        }
        currentPowerWatts = watts
        return snapshot(watts: watts, target: currentTargetPercent)
    }

    func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        beginWrite()
        defer { finishWrite() }
        targetWrites.append(percent)
        currentTargetPercent = percent
        return snapshot(watts: currentPowerWatts, target: percent)
    }

    func prepareCount() -> Int { prepareCalls }
    func cancelledPreparationCount() -> Int { cancelledPreparations }
    func writtenPowerValues() -> [Int] { powerWrites }
    func writtenTargetValues() -> [Int] { targetWrites }
    func maximumConcurrentWriteCount() -> Int { highestConcurrentWriteCount }

    func suspendPowerWrites() {
        powerWritesAreSuspended = true
    }

    func rejectPowerWrites() {
        powerWritesFail = true
    }

    func resumePowerWrites() {
        powerWritesAreSuspended = false
        let waiters = powerWriteWaiters
        powerWriteWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func snapshot(watts: Int, target: Int) -> BikeChargePowerControlSnapshot {
        .init(
            vcuFirmware: "1.12.0",
            isFirmwareCompatible: true,
            readRequestHex: "00 04",
            readResponseHex: "01 04",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 20,
                chargePowerWatts: watts,
                maximumStateOfChargeDeciPercent: target * 10,
                standardChargerMaximumPowerWatts: 3_300,
                backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: "01 04 01",
            didPassNoOpWrite: passesNoOpWrite,
            logLines: []
        )
    }

    private func beginWrite() {
        activeWrites += 1
        highestConcurrentWriteCount = max(highestConcurrentWriteCount, activeWrites)
    }

    private func finishWrite() {
        activeWrites -= 1
    }
}

private enum ChargeControlRepositoryError: Error {
    case writeRejected
}
