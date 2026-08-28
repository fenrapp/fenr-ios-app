import Foundation
import StarkProtocol

@MainActor
final class BikeBLEPowerModeConfigurationCoordinator {
    private let transport: any BikeBLEPowerModeConfigurationTransporting
    private let eventEmitter: BikeBLEEventEmitter

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

    func reset() {
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
    private func readTractionControlConfiguration(
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

    private func report(_ detail: String) async {
        console(detail)
        await emitDebug(detail)
    }

    private func emitDebug(_ detail: String) async {
        await eventEmitter.send(.debug(.init(title: "Power modes", detail: detail)))
    }

    private func console(_ message: String) {
        BikePowerModeDebugLog.log(message)
    }

    private enum Constants {
        static let interRequestDelay = Duration.milliseconds(150)
    }
}
