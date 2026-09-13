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
        mapIndex: Int, powerTractionPercent: Double, brakingTractionPercent: Double
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
        let compatibility = try await readTractionControlFirmwareCompatibility()
        try checkTractionSession(token)
        guard compatibility.isCompatible else { throw BikeSDKTractionControlError.unavailable }
        preparedTractionConfigurations[mapIndex] = nil
        await report("4005 TC map \(mapIndex) user write firmware=\(compatibility.firmware)")
        try await writeUserTraction(packet, token: token)
        let verified = try await confirmUserTraction(mapIndex: mapIndex, token: token)
        guard verified == desired else { throw BikeSDKTractionControlError.mismatch(verified) }
        return verified
    }

    private func writeUserTraction(_ packet: Data, token: Int) async throws {
        try checkTractionSession(token)
        do { try await transport.writeConfiguration(packet) } catch is CancellationError {
            throw CancellationError()
        } catch {
            await report("4005 TC write failed: \(error.localizedDescription)")
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
            await report("4005 TC map \(mapIndex) confirmation failed: \(error.localizedDescription)")
            try checkTractionSession(token)
            throw BikeSDKTractionControlError.confirmationUnavailable
        }
    }

    private func tractionSnapshot(_ value: StarkTractionControlConfigurationPayload) -> BikeSDKTractionControlSnapshot {
        .init(mapIndex: value.mapIndex, powerRaw: value.powerRaw, brakingRaw: value.brakingRaw)
    }
}
