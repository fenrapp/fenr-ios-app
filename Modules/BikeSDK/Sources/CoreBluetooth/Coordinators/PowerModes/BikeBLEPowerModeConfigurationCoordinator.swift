import Foundation
import StarkProtocol

@MainActor
final class BikeBLEPowerModeConfigurationCoordinator {
    let transport: any BikeBLEPowerModeConfigurationTransporting
    let eventEmitter: BikeBLEEventEmitter
    private var preparedConfigurations: [Int: StarkPowerModeConfigurationPayload] = [:]
    var preparedTractionConfigurations: [Int: StarkTractionControlConfigurationPayload] = [:]

    init(
        transport: any BikeBLEPowerModeConfigurationTransporting,
        eventEmitter: BikeBLEEventEmitter
    ) {
        self.transport = transport
        self.eventEmitter = eventEmitter
    }

    func refresh() async throws {
        try await readPowerModeConfigurations()
        try await readTractionControlConfigurations()
    }

    func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try await readPowerModeConfiguration(mapIndex: mapIndex)
    }

    func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        try await readTractionControlConfiguration(mapIndex: mapIndex)
    }

    func preparePowerModeControl(mapIndex: Int) async throws {
        try transport.ensureReady()
        preparedConfigurations[mapIndex] = nil
        let versionData = try await transport.readVersions()
        guard let firmware = StarkFirmwareVersionParser.parseVCUPic(from: versionData) else {
            throw BikeSDKError.operationFailed(
                "Power mode control requires a recognized VCU PIC firmware"
            )
        }
        let configuration = try await readPowerModeConfiguration(mapIndex: mapIndex)
        guard StarkPowerModeConfigurationCommand.isSupportedReadCurve(
            configuration.curve,
            mapIndex: mapIndex
        ) else {
            throw BikeSDKError.operationFailed(
                "Map \(mapIndex + 1) returned unexpected curve selector \(configuration.curve); "
                    + "base power and regeneration controls are unavailable"
            )
        }
        let noOpPacket = try StarkPowerModeConfigurationCommand.noOpWritePacket(
            configuration: configuration
        )
        try await transport.writeConfiguration(noOpPacket)
        try await Task.sleep(for: Constants.writeVerificationDelay)
        let verified = try await readPowerModeConfiguration(mapIndex: mapIndex)
        guard baseValuesMatch(verified, configuration),
              StarkPowerModeConfigurationCommand.isSupportedReadCurve(
                  verified.curve,
                  mapIndex: mapIndex
              )
        else {
            throw BikeSDKError.operationFailed(
                "Power mode no-op verification returned different map values"
            )
        }
        preparedConfigurations[mapIndex] = verified
        await report(
            "4005 map \(mapIndex) control prepared firmware=\(firmware.description) "
                + "packet=\(noOpPacket.bikeSDKHexString)"
        )
    }

    func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        guard let prepared = preparedConfigurations[mapIndex] else {
            throw BikeSDKError.operationFailed(
                "Power mode control has not passed the no-op guard for map \(mapIndex + 1)"
            )
        }
        guard StarkPowerModeConfigurationCommand.isSupportedReadCurve(
            prepared.curve,
            mapIndex: mapIndex
        ) else {
            preparedConfigurations[mapIndex] = nil
            throw BikeSDKError.operationFailed(
                "The selected map returned an unexpected curve selector"
            )
        }
        let writeCurve = try StarkPowerModeConfigurationCommand.normalizedWriteCurve(
            mapIndex: mapIndex
        )
        let packet = try StarkPowerModeConfigurationCommand.writePacket(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent,
            curve: writeCurve
        )
        try await transport.writeConfiguration(packet)
        try await Task.sleep(for: Constants.writeVerificationDelay)
        let verified = try await readPowerModeConfiguration(mapIndex: mapIndex)
        guard verified.horsepower == horsepower,
              Int(verified.regenerativeBrakingPercent.rounded()) == regenerativeBrakingPercent,
              StarkPowerModeConfigurationCommand.isSupportedReadCurve(
                  verified.curve,
                  mapIndex: mapIndex
              )
        else {
            preparedConfigurations[mapIndex] = nil
            throw BikeSDKError.operationFailed(
                "Power mode write was not confirmed by the VCU response"
            )
        }
        preparedConfigurations[mapIndex] = verified
        await report(
            "4005 map \(mapIndex) write verified hp=\(horsepower) "
                + "regen=\(regenerativeBrakingPercent)% packet=\(packet.bikeSDKHexString)"
        )
    }

    func reset() {
        preparedConfigurations.removeAll()
        preparedTractionConfigurations.removeAll()
        console("session reset")
    }

    private func readPowerModeConfigurations() async throws {
        var receivedMapCount = 0
        var firstFailure: (any Error)?

        for mapIndex in StarkPowerModeConfigurationCommand.mapIndexes {
            try Task.checkCancellation()
            do {
                _ = try await readPowerModeConfiguration(mapIndex: mapIndex)
                receivedMapCount += 1
                try await Task.sleep(for: Constants.interRequestDelay)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if firstFailure == nil {
                    firstFailure = error
                }
                await emitMapFailure(kind: "power", mapIndex: mapIndex, error: error)
            }
        }

        guard receivedMapCount > 0 else {
            let detail = firstFailure.map { " First failure: \($0.localizedDescription)" } ?? ""
            throw BikeSDKError.operationFailed(
                "No power mode configuration was received from 4005.\(detail)"
            )
        }
        console(
            "power configurations received \(receivedMapCount)/"
                + "\(StarkPowerModeConfigurationCommand.mapIndexes.count)"
        )
    }

    private func readTractionControlConfigurations() async throws {
        var receivedMapCount = 0

        for mapIndex in StarkPowerModeConfigurationCommand.mapIndexes {
            do {
                try Task.checkCancellation()
                _ = try await readTractionControlConfiguration(mapIndex: mapIndex)
                receivedMapCount += 1
                try await Task.sleep(for: Constants.interRequestDelay)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await emitMapFailure(kind: "TC", mapIndex: mapIndex, error: error)
            }
        }
        console(
            "TC configurations received \(receivedMapCount)/"
                + "\(StarkPowerModeConfigurationCommand.mapIndexes.count)"
        )
    }

    @discardableResult
    private func readPowerModeConfiguration(
        mapIndex: Int
    ) async throws -> StarkPowerModeConfigurationPayload {
        let request = try StarkPowerModeConfigurationCommand.readPacket(mapIndex: mapIndex)
        let response = try await transport.readConfiguration(
            request: request,
            operationName: "4005 power mode \(mapIndex) read",
            allowLiveTelemetrySession: false
        )
        let payload = try StarkPowerModeConfigurationCommand.decodeResponse(
            response,
            expectedMapIndex: mapIndex
        )
        await report(
            "4005 power map \(mapIndex) decoded hp=\(payload.horsepower) "
                + "regen=\(payload.regenerativeBrakingPercent)%"
        )
        await eventEmitter.send(.telemetry(.powerModeConfiguration(payload)))
        return payload
    }

    @discardableResult
    func readTractionControlConfiguration(
        mapIndex: Int
    ) async throws -> StarkTractionControlConfigurationPayload {
        let request = try StarkTractionControlConfigurationCommand.readPacket(mapIndex: mapIndex)
        let response = try await transport.readConfiguration(
            request: request,
            operationName: "4005 traction control \(mapIndex) read",
            allowLiveTelemetrySession: false
        )
        let payload = try StarkTractionControlConfigurationCommand.decodeResponse(
            response,
            expectedMapIndex: mapIndex
        )
        await report(
            "4005 TC map \(mapIndex) decoded power=\(payload.powerPercent)% "
                + "braking=\(payload.brakingPercent)%"
        )
        await eventEmitter.send(.telemetry(.tractionControlConfiguration(payload)))
        return payload
    }

    private func emitMapFailure(kind: String, mapIndex: Int, error: Error) async {
        await report(
            "4005 \(kind) map \(mapIndex) failed: \(error.localizedDescription)"
        )
    }

    private func baseValuesMatch(
        _ lhs: StarkPowerModeConfigurationPayload,
        _ rhs: StarkPowerModeConfigurationPayload
    ) -> Bool {
        lhs.mapIndex == rhs.mapIndex
            && lhs.torqueRaw == rhs.torqueRaw
            && lhs.regenerationRaw == rhs.regenerationRaw
    }

    func report(_ detail: String) async {
        console(detail)
        await emitDebug(detail)
    }

    private func emitDebug(_ detail: String) async {
        await eventEmitter.send(.debug(.init(title: "Power modes", detail: detail)))
    }

    private func console(_ message: String) {
        BikePowerModeDebugLog.log(message)
    }

    enum Constants {
        static let interRequestDelay = Duration.milliseconds(150)
        static let writeVerificationDelay = Duration.milliseconds(150)
    }
}
