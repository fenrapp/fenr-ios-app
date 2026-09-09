import Foundation
import StarkProtocol

extension BikeBLEPowerModeConfigurationCoordinator {
    func checkTractionSession(_ token: Int) throws {
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
        do { try transport.ensureReady() } catch { throw BikeSDKTractionControlError.connectionRecoveryRequired }
    }

    func readTractionControlFirmwareCompatibility() async throws -> BikeSDKTractionControlFirmwareCompatibility {
        let token = generation
        try checkTractionSession(token)
        let versions = try await transport.readVersions()
        try checkTractionSession(token)
        guard let version = StarkFirmwareVersionParser.parseVCUPic(from: versions) else {
            throw BikeSDKTractionControlError.unavailable
        }
        return .init(firmware: version.description, isCompatible: version.isTractionControlCompatible)
    }

    func applyUserTractionControlConfiguration(
        mapIndex: Int, powerTractionPercent: Double, brakingTractionPercent: Double,
        expected: BikeSDKTractionControlSnapshot?
    ) async throws -> BikeSDKTractionControlSnapshot {
        let token = generation
        try checkTractionSession(token)
        let packet = try StarkTractionControlConfigurationCommand.writePacket(
            mapIndex: mapIndex, powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
        let desired = BikeSDKTractionControlSnapshot(
            mapIndex: mapIndex,
            powerRaw: try StarkTractionControlConfigurationCommand.rawValue(forPercent: powerTractionPercent),
            brakingRaw: try StarkTractionControlConfigurationCommand.rawValue(forPercent: brakingTractionPercent)
        )
        guard expected == nil || expected?.mapIndex == mapIndex else { throw BikeSDKTractionControlError.rejected }
        let compatibility = try await readTractionControlFirmwareCompatibility()
        try checkTractionSession(token)
        guard compatibility.isCompatible else { throw BikeSDKTractionControlError.unavailable }
        preparedTractionConfigurations[mapIndex] = nil
        let previous = try await readOptionalUserTraction(mapIndex: mapIndex, token: token)
        try checkTractionSession(token)
        if let previous {
            let actual = tractionSnapshot(previous)
            if let expected, expected != actual { throw BikeSDKTractionControlError.changed(actual) }
            if actual == desired { return actual }
            // A readable baseline always retains the exact no-op guard.
            let noOp = try StarkTractionControlConfigurationCommand.noOpWritePacket(configuration: previous)
            try await writeUserTraction(noOp, token: token)
            let verified = try await confirmUserTraction(mapIndex: mapIndex, token: token)
            guard verified == actual else { throw BikeSDKTractionControlError.mismatch(verified) }
        }
        try checkTractionSession(token)
        // Only this user-initiated operation may proceed without a readable baseline.
        try await writeUserTraction(packet, token: token)
        let verified = try await confirmUserTraction(mapIndex: mapIndex, token: token)
        guard verified == desired else { throw BikeSDKTractionControlError.mismatch(verified) }
        return verified
    }

    private func readOptionalUserTraction(
        mapIndex: Int, token: Int
    ) async throws -> StarkTractionControlConfigurationPayload? {
        do {
            let value = try await readTractionControlConfiguration(mapIndex: mapIndex)
            try checkTractionSession(token)
            return value
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try checkTractionSession(token)
            return nil
        }
    }

    private func writeUserTraction(_ packet: Data, token: Int) async throws {
        try checkTractionSession(token)
        do { try await transport.writeConfiguration(packet) } catch is CancellationError {
            throw CancellationError()
        } catch {
            try checkTractionSession(token)
            if case StarkProtocolError.configurationRequestFailed = error {
                throw BikeSDKTractionControlError.rejected
            }
            throw BikeSDKTractionControlError.confirmationUnavailable
        }
        try checkTractionSession(token)
    }

    private func confirmUserTraction(mapIndex: Int, token: Int) async throws -> BikeSDKTractionControlSnapshot {
        try await Task.sleep(for: Constants.writeVerificationDelay)
        try checkTractionSession(token)
        do {
            let value = try await readTractionControlConfiguration(mapIndex: mapIndex)
            try checkTractionSession(token)
            return tractionSnapshot(value)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try checkTractionSession(token)
            throw BikeSDKTractionControlError.confirmationUnavailable
        }
    }

    private func tractionSnapshot(_ value: StarkTractionControlConfigurationPayload) -> BikeSDKTractionControlSnapshot {
        .init(mapIndex: value.mapIndex, powerRaw: value.powerRaw, brakingRaw: value.brakingRaw)
    }
}
