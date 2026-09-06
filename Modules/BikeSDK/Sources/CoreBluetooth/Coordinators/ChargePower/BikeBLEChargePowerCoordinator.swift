import BLETraceDomain
import Foundation
import StarkProtocol

@MainActor
final class BikeBLEChargePowerCoordinator {
    private let captureState: BLETraceCaptureState
    private let transport: any BikeBLEChargePowerConfigurationTransporting
    private let verificationWaiter: any BikeBLEChargePowerVerificationWaiting
    private var cachedChargePowerConfiguration: StarkChargerConfiguration?
    private var cachedChargerType: StarkChargerType?
    private var cachedChargePowerFirmware: String?
    private var didPassChargePowerNoOp = false

    init(
        transport: any BikeBLEChargePowerConfigurationTransporting,
        verificationWaiter: any BikeBLEChargePowerVerificationWaiting,
        captureState: BLETraceCaptureState
    ) {
        self.captureState = captureState
        self.transport = transport
        self.verificationWaiter = verificationWaiter
    }

    func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot {
        clearGuardState()
        let firmwareRead = try await readVCUFirmware()
        let firmware = firmwareRead.version
        let isCompatible = firmware?.isChargePowerControlCompatible == true
        guard isCompatible else {
            throw BikeSDKError.operationFailed(
                "VCU PIC firmware is not compatible with charge power control; "
                    + "4001 raw=\(firmwareRead.rawHex); "
                    + "parsed=\(firmware?.description ?? "unknown"); "
                    + "versions=\(firmwareRead.versionDescriptions.joined(separator: ","))"
            )
        }

        let readResult = try await readChargeConfiguration()
        let configuration = readResult.configuration
        let noOpWrite = try StarkChargerConfigurationCommand.encodeWrite(configuration)
        try await transport.writeConfiguration(noOpWrite)
        try await verificationWaiter.wait()
        let verifiedResult = try await readChargeConfiguration(matching: configuration)

        cachedChargePowerConfiguration = verifiedResult.configuration
        cachedChargerType = StarkChargerType(rawValue: context.chargerTypeRaw)
        cachedChargePowerFirmware = firmware?.description
        didPassChargePowerNoOp = true

        let includesDiagnostics = captureState.isRecording
        return BikeSDKChargePowerControlSnapshot(
            vcuFirmware: firmware?.description,
            isFirmwareCompatible: isCompatible,
            readRequestHex: includesDiagnostics ? StarkChargerConfigurationCommand.readPacket.bikeSDKHexString : "",
            readResponseHex: includesDiagnostics ? verifiedResult.responseHex : "",
            parsedConfig: verifiedResult.configuration,
            lastWriteHex: includesDiagnostics ? noOpWrite.bikeSDKHexString : nil,
            didPassNoOpWrite: true,
            logLines: includesDiagnostics ? [
                "4001 raw: \(firmwareRead.rawHex)",
                "4001 parsed VCU PIC: \(firmware?.description ?? "unknown")",
                "4001 parsed versions: \(firmwareRead.versionDescriptions.joined(separator: ","))",
                readResult.logLine,
                "4005 no-op write confirmed: \(noOpWrite.bikeSDKHexString)"
            ] : []
        )
    }

    func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        guard
            didPassChargePowerNoOp,
            let configuration = cachedChargePowerConfiguration,
            let chargerType = cachedChargerType
        else {
            throw BikeSDKError.operationFailed("Charge power control has not passed the no-op guard")
        }

        let nextConfiguration = configuration.settingChargePower(watts, chargerType: chargerType)
        let writePayload = try StarkChargerConfigurationCommand.encodeWrite(nextConfiguration)
        do {
            try await transport.writeConfiguration(writePayload)
            try await verificationWaiter.wait()
            let verifiedResult = try await readChargeConfiguration(matching: nextConfiguration)
            cachedChargePowerConfiguration = verifiedResult.configuration

            let includesDiagnostics = captureState.isRecording
            return BikeSDKChargePowerControlSnapshot(
                vcuFirmware: cachedChargePowerFirmware,
                isFirmwareCompatible: true,
                readRequestHex: includesDiagnostics ? StarkChargerConfigurationCommand.readPacket.bikeSDKHexString : "",
                readResponseHex: includesDiagnostics ? verifiedResult.responseHex : "",
                parsedConfig: verifiedResult.configuration,
                lastWriteHex: includesDiagnostics ? writePayload.bikeSDKHexString : nil,
                didPassNoOpWrite: true,
                logLines: includesDiagnostics ? ["4005 write confirmed: \(writePayload.bikeSDKHexString)"] : []
            )
        } catch {
            clearGuardState()
            throw error
        }
    }

    func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        guard didPassChargePowerNoOp, let configuration = cachedChargePowerConfiguration else {
            throw BikeSDKError.operationFailed("Charge target control has not passed the no-op guard")
        }

        let targetPercent = max(1, min(100, percent))
        let nextConfiguration = configuration.settingMaximumStateOfCharge(percent: targetPercent)
        let writePayload = try StarkChargerConfigurationCommand.encodeWrite(nextConfiguration)
        do {
            try await transport.writeConfiguration(writePayload)
            try await verificationWaiter.wait()
            let verifiedResult = try await readChargeConfiguration(matching: nextConfiguration)
            cachedChargePowerConfiguration = verifiedResult.configuration

            let includesDiagnostics = captureState.isRecording
            return BikeSDKChargePowerControlSnapshot(
                vcuFirmware: cachedChargePowerFirmware,
                isFirmwareCompatible: true,
                readRequestHex: includesDiagnostics ? StarkChargerConfigurationCommand.readPacket.bikeSDKHexString : "",
                readResponseHex: includesDiagnostics ? verifiedResult.responseHex : "",
                parsedConfig: verifiedResult.configuration,
                lastWriteHex: includesDiagnostics ? writePayload.bikeSDKHexString : nil,
                didPassNoOpWrite: true,
                logLines: includesDiagnostics ? ["4005 target write confirmed: \(writePayload.bikeSDKHexString)"] : []
            )
        } catch {
            clearGuardState()
            throw error
        }
    }

    func reset() {
        clearGuardState()
    }

    private func readVCUFirmware() async throws -> BikeBLEVCUFirmwareRead {
        let data = try await transport.readVersions()
        return BikeBLEVCUFirmwareRead(
            data: data,
            version: StarkFirmwareVersionParser.parseVCUPic(from: data)
        )
    }

    private func readChargeConfiguration() async throws -> BikeBLEChargePowerConfigurationReadResult {
        let data = try await transport.readConfiguration(
            request: StarkChargerConfigurationCommand.readPacket,
            operationName: "4005 charge configuration read",
            allowLiveTelemetrySession: false
        )
        return .init(
            configuration: try StarkChargerConfigurationCommand.decodeResponse(data),
            data: data
        )
    }

    private func readChargeConfiguration(
        matching expectedConfiguration: StarkChargerConfiguration
    ) async throws -> BikeBLEChargePowerConfigurationReadResult {
        let maximumAttempts = 3
        var lastResult: BikeBLEChargePowerConfigurationReadResult?
        for attempt in 1...maximumAttempts {
            let result = try await readChargeConfiguration()
            if result.configuration == expectedConfiguration {
                return result
            }
            lastResult = result
            if attempt < maximumAttempts {
                try await verificationWaiter.wait()
            }
        }

        clearGuardState()
        throw BikeSDKError.operationFailed(
            "Charge configuration was not confirmed after \(maximumAttempts) fresh reads; "
                + "expected=\(expectedConfiguration) actual=\(String(describing: lastResult?.configuration))"
        )
    }

    private func clearGuardState() {
        cachedChargePowerConfiguration = nil
        cachedChargerType = nil
        cachedChargePowerFirmware = nil
        didPassChargePowerNoOp = false
    }

}

private struct BikeBLEVCUFirmwareRead {
    let data: Data
    let version: StarkFirmwareVersion?

    var rawHex: String { data.bikeSDKHexString }
    var versionDescriptions: [String] {
        StarkFirmwareVersionParser.parseVersionBlockDescriptions(from: data)
    }
}

private struct BikeBLEChargePowerConfigurationReadResult {
    let configuration: StarkChargerConfiguration
    let data: Data

    var responseHex: String { data.bikeSDKHexString }
    var logLine: String { "4005 read response: \(responseHex)" }
}
