import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
final class BikeBLEChargePowerCoordinator {
    private let transport: BikeBLEVCUConfigurationTransport
    private var cachedChargePowerConfiguration: StarkChargerConfiguration?
    private var cachedChargePowerReadResponseHex: String?
    private var cachedChargePowerFirmware: String?
    private var didPassChargePowerNoOp = false

    init(transport: BikeBLEVCUConfigurationTransport) {
        self.transport = transport
    }

    func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot {
        try transport.ensureReady()
        clearGuardState()
        let configCharacteristic = try transport.configurationCharacteristic()
        let firmwareRead = try await readVCUFirmware()
        let firmware = firmwareRead.version
        let isCompatible = firmware?.isChargePowerControlCompatible == true
        let parsedVersions = firmwareRead.versionDescriptions.joined(separator: ",")
        guard isCompatible else {
            throw BikeSDKError.operationFailed(
                "VCU PIC firmware is not compatible with charge power control; "
                    + "4001 raw=\(firmwareRead.rawHex); "
                    + "parsed=\(firmware?.description ?? "unknown"); "
                    + "versions=\(parsedVersions)"
            )
        }

        let readResult = try await readChargeConfigurationIfPermitted(
            characteristic: configCharacteristic,
            context: context
        )
        let configuration = readResult.configuration
        let noOpWrite = try StarkChargerConfigurationCommand.encodeWrite(configuration)
        try await transport.writeConfiguration(noOpWrite)

        cachedChargePowerConfiguration = configuration
        cachedChargePowerReadResponseHex = readResult.responseHex
        cachedChargePowerFirmware = firmware?.description
        didPassChargePowerNoOp = true

        return BikeSDKChargePowerControlSnapshot(
            vcuFirmware: firmware?.description,
            isFirmwareCompatible: isCompatible,
            readRequestHex: StarkChargerConfigurationCommand.readPacket.bikeSDKHexString,
            readResponseHex: readResult.responseHex,
            parsedConfig: configuration,
            lastWriteHex: noOpWrite.bikeSDKHexString,
            didPassNoOpWrite: true,
            logLines: [
                "4001 raw: \(firmwareRead.rawHex)",
                "4001 parsed VCU PIC: \(firmware?.description ?? "unknown")",
                "4001 parsed versions: \(parsedVersions)",
                readResult.logLine,
                "4005 no-op write confirmed: \(noOpWrite.bikeSDKHexString)"
            ]
        )
    }

    func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        _ = try transport.configurationCharacteristic()
        guard didPassChargePowerNoOp, let configuration = cachedChargePowerConfiguration else {
            throw BikeSDKError.operationFailed("Charge power control has not passed the no-op guard")
        }

        let nextConfiguration = configuration.settingChargePower(watts)
        let writePayload = try StarkChargerConfigurationCommand.encodeWrite(nextConfiguration)
        try await transport.writeConfiguration(writePayload)
        cachedChargePowerConfiguration = nextConfiguration

        return BikeSDKChargePowerControlSnapshot(
            vcuFirmware: cachedChargePowerFirmware,
            isFirmwareCompatible: true,
            readRequestHex: StarkChargerConfigurationCommand.readPacket.bikeSDKHexString,
            readResponseHex: cachedChargePowerReadResponseHex ?? "",
            parsedConfig: nextConfiguration,
            lastWriteHex: writePayload.bikeSDKHexString,
            didPassNoOpWrite: true,
            logLines: ["4005 write confirmed: \(writePayload.bikeSDKHexString)"]
        )
    }

    func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        _ = try transport.configurationCharacteristic()
        guard didPassChargePowerNoOp, let configuration = cachedChargePowerConfiguration else {
            throw BikeSDKError.operationFailed("Charge target control has not passed the no-op guard")
        }

        let targetPercent = max(1, min(100, percent))
        let nextConfiguration = configuration.settingMaximumStateOfCharge(percent: targetPercent)
        let writePayload = try StarkChargerConfigurationCommand.encodeWrite(nextConfiguration)
        try await transport.writeConfiguration(writePayload)
        cachedChargePowerConfiguration = nextConfiguration

        return BikeSDKChargePowerControlSnapshot(
            vcuFirmware: cachedChargePowerFirmware,
            isFirmwareCompatible: true,
            readRequestHex: StarkChargerConfigurationCommand.readPacket.bikeSDKHexString,
            readResponseHex: cachedChargePowerReadResponseHex ?? "",
            parsedConfig: nextConfiguration,
            lastWriteHex: writePayload.bikeSDKHexString,
            didPassNoOpWrite: true,
            logLines: ["4005 target write confirmed: \(writePayload.bikeSDKHexString)"]
        )
    }

    func didWriteValue(characteristic: CBCharacteristic, error: Error?) {
        transport.completeWriteIfNeeded(characteristic: characteristic, error: error)
    }

    func completeChargePowerReadIfNeeded(
        characteristic: CBCharacteristic,
        error: Error?
    ) -> Bool {
        transport.completeReadIfNeeded(characteristic: characteristic, error: error)
    }

    func reset() {
        clearGuardState()
    }

    private func readVCUFirmware() async throws -> BikeBLEVCUFirmwareRead {
        let data = try await transport.readVersions()
        return BikeBLEVCUFirmwareRead(
            rawHex: data.bikeSDKHexString,
            version: StarkFirmwareVersionParser.parseVCUPic(from: data),
            versionDescriptions: StarkFirmwareVersionParser.parseVersionBlockDescriptions(from: data)
        )
    }

    private func readChargeConfigurationIfPermitted(
        characteristic: CBCharacteristic,
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeBLEChargePowerConfigurationReadResult {
        guard characteristic.properties.contains(.read) else {
            return try fallbackChargeConfiguration(
                context: context,
                reason: "4005 read unavailable: characteristic does not advertise read"
            )
        }
        do {
            let data = try await transport.readConfiguration(
                request: StarkChargerConfigurationCommand.readPacket,
                operationName: "4005 charge configuration read"
            )
            return .init(
                configuration: try StarkChargerConfigurationCommand.decodeResponse(data),
                responseHex: data.bikeSDKHexString,
                logLine: "4005 read response: \(data.bikeSDKHexString)"
            )
        } catch {
            return try fallbackChargeConfiguration(
                context: context,
                reason: "4005 read failed: \(error.localizedDescription)"
            )
        }
    }

    private func fallbackChargeConfiguration(
        context: BikeSDKChargePowerTelemetryContext,
        reason: String
    ) throws -> BikeBLEChargePowerConfigurationReadResult {
        let chargerType = StarkChargerType(rawValue: context.chargerTypeRaw)
        let currentDeciAmperes = Int((context.maximumCurrentAmperes * 10).rounded())
        let currentPowerWatts = Int(context.maximumPowerWatts.rounded())
        guard currentDeciAmperes > 0, currentPowerWatts >= StarkChargePowerControlLimits.minimumWatts else {
            throw BikeSDKError.operationFailed(
                reason + "; 5001 fallback unavailable because current/power telemetry is invalid "
                    + "current=\(currentDeciAmperes) dA power=\(currentPowerWatts) W"
            )
        }
        let maximumSocDeciPercent = max(0, min(1_000, context.maximumStateOfChargePercent * 10))
        let configuration = StarkChargerConfiguration(
            chargeCurrentDeciAmperes: currentDeciAmperes,
            chargePowerWatts: currentPowerWatts,
            maximumStateOfChargeDeciPercent: maximumSocDeciPercent,
            standardChargerMaximumPowerWatts: StarkChargePowerControlLimits.standardMaximumWatts,
            backpackChargerMaximumPowerWatts: chargerType.maximumChargePowerWatts
        )
        return .init(
            configuration: configuration,
            responseHex: "",
            logLine: reason + "; using 5001 fallback current=\(currentDeciAmperes) dA "
                + "power=\(currentPowerWatts) W maxSoc=\(maximumSocDeciPercent) d% "
                + "requested=\(Int((context.requestedCurrentAmperes * 10).rounded())) dA "
                + "maximum=\(Int((context.maximumCurrentAmperes * 10).rounded())) dA "
                + "type=\(chargerType.displayName) raw=\(context.chargerTypeRaw)"
        )
    }

    private func clearGuardState() {
        cachedChargePowerConfiguration = nil
        cachedChargePowerReadResponseHex = nil
        cachedChargePowerFirmware = nil
        didPassChargePowerNoOp = false
    }

}

private struct BikeBLEVCUFirmwareRead {
    let rawHex: String
    let version: StarkFirmwareVersion?
    let versionDescriptions: [String]
}

private struct BikeBLEChargePowerConfigurationReadResult {
    let configuration: StarkChargerConfiguration
    let responseHex: String
    let logLine: String
}
