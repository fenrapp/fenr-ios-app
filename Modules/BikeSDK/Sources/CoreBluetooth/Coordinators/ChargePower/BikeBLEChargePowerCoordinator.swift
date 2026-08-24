import CoreBluetooth
import Foundation
import StarkProtocol

@MainActor
final class BikeBLEChargePowerCoordinator {
    private let transport: BikeBLEChargePowerTransport
    private var cachedChargePowerConfiguration: StarkChargerConfiguration?
    private var cachedChargePowerReadResponseHex: String?
    private var cachedChargePowerFirmware: String?
    private var didPassChargePowerNoOp = false

    init(transport: BikeBLEChargePowerTransport) {
        self.transport = transport
    }

    func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot {
        try transport.ensureReady()
        clearGuardState()
        let peripheral = try transport.authenticatedPeripheral()
        let configCharacteristic = try transport.configurationCharacteristic()
        let firmwareRead = try await readVCUFirmware(peripheral: peripheral)
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
            peripheral: peripheral,
            characteristic: configCharacteristic,
            context: context
        )
        let configuration = readResult.configuration
        let noOpWrite = try StarkChargerConfigurationCommand.encodeWrite(configuration)
        try await writeChargeConfiguration(
            noOpWrite,
            peripheral: peripheral,
            characteristic: configCharacteristic
        )

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
        let peripheral = try transport.authenticatedPeripheral()
        let configCharacteristic = try transport.configurationCharacteristic()
        guard didPassChargePowerNoOp, let configuration = cachedChargePowerConfiguration else {
            throw BikeSDKError.operationFailed("Charge power control has not passed the no-op guard")
        }

        let nextConfiguration = configuration.settingChargePower(watts)
        let writePayload = try StarkChargerConfigurationCommand.encodeWrite(nextConfiguration)
        try await writeChargeConfiguration(
            writePayload,
            peripheral: peripheral,
            characteristic: configCharacteristic
        )
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
        let peripheral = try transport.authenticatedPeripheral()
        let configCharacteristic = try transport.configurationCharacteristic()
        guard didPassChargePowerNoOp, let configuration = cachedChargePowerConfiguration else {
            throw BikeSDKError.operationFailed("Charge target control has not passed the no-op guard")
        }

        let targetPercent = max(1, min(100, percent))
        let nextConfiguration = configuration.settingMaximumStateOfCharge(percent: targetPercent)
        let writePayload = try StarkChargerConfigurationCommand.encodeWrite(nextConfiguration)
        try await writeChargeConfiguration(
            writePayload,
            peripheral: peripheral,
            characteristic: configCharacteristic
        )
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
        transport.reset()
        clearGuardState()
    }

    private func readVCUFirmware(peripheral: CBPeripheral) async throws -> BikeBLEVCUFirmwareRead {
        let characteristic = try transport.versionsCharacteristic()
        let data = try await transport.read(
            peripheral: peripheral,
            characteristic: characteristic,
            operationName: "4001 read"
        )
        return BikeBLEVCUFirmwareRead(
            rawHex: data.bikeSDKHexString,
            version: StarkFirmwareVersionParser.parseVCUPic(from: data),
            versionDescriptions: StarkFirmwareVersionParser.parseVersionBlockDescriptions(from: data)
        )
    }

    private func requestChargeConfiguration(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) async throws -> Data {
        try await transport.write(
            StarkChargerConfigurationCommand.readPacket,
            peripheral: peripheral,
            characteristic: characteristic
        )
        return try await transport.read(
            peripheral: peripheral,
            characteristic: characteristic,
            operationName: "4005 read"
        )
    }

    private func readChargeConfigurationIfPermitted(
        peripheral: CBPeripheral,
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
            let data = try await requestChargeConfiguration(
                peripheral: peripheral,
                characteristic: characteristic
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

    private func writeChargeConfiguration(
        _ payload: Data,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) async throws {
        try await transport.write(payload, peripheral: peripheral, characteristic: characteristic)
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
