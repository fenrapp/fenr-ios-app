import Foundation
import StarkProtocol

extension BikeBLEPowerModeConfigurationCoordinator {
    func prepareTractionControl(mapIndex: Int) async throws {
        try transport.ensureReady()
        preparedTractionConfigurations[mapIndex] = nil
        let versionData = try await transport.readVersions()
        guard let firmware = StarkFirmwareVersionParser.parseVCUPic(from: versionData),
              firmware.isTractionControlCompatible
        else {
            throw BikeSDKError.operationFailed(
                "Traction control requires VCU PIC firmware 1.10.1 or newer"
            )
        }
        let configuration = try await readTractionControlConfiguration(mapIndex: mapIndex)
        let noOpPacket = try StarkTractionControlConfigurationCommand.noOpWritePacket(
            configuration: configuration
        )
        try await transport.writeConfiguration(noOpPacket)
        try await Task.sleep(for: Constants.writeVerificationDelay)
        let verified = try await readTractionControlConfiguration(mapIndex: mapIndex)
        guard verified == configuration else {
            throw BikeSDKError.operationFailed(
                "Traction-control no-op verification returned different map values"
            )
        }
        preparedTractionConfigurations[mapIndex] = verified
        await report(
            "4005 TC map \(mapIndex) control prepared firmware=\(firmware.description) "
                + "packet=\(noOpPacket.bikeSDKHexString)"
        )
    }

    func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        guard preparedTractionConfigurations[mapIndex] != nil else {
            throw BikeSDKError.operationFailed(
                "Traction control has not passed the no-op guard for map \(mapIndex + 1)"
            )
        }
        let expectedPowerRaw = try StarkTractionControlConfigurationCommand.rawValue(
            forPercent: powerTractionPercent
        )
        let expectedBrakingRaw = try StarkTractionControlConfigurationCommand.rawValue(
            forPercent: brakingTractionPercent
        )
        let packet = try StarkTractionControlConfigurationCommand.writePacket(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
        try await transport.writeConfiguration(packet)
        try await Task.sleep(for: Constants.writeVerificationDelay)
        let verified = try await readTractionControlConfiguration(mapIndex: mapIndex)
        guard verified.powerRaw == expectedPowerRaw,
              verified.brakingRaw == expectedBrakingRaw
        else {
            preparedTractionConfigurations[mapIndex] = nil
            throw BikeSDKError.operationFailed(
                "Traction-control write was not confirmed by the VCU response"
            )
        }
        preparedTractionConfigurations[mapIndex] = verified
        await report(
            "4005 TC map \(mapIndex) write verified power=\(powerTractionPercent)% "
                + "braking=\(brakingTractionPercent)% packet=\(packet.bikeSDKHexString)"
        )
    }
}
