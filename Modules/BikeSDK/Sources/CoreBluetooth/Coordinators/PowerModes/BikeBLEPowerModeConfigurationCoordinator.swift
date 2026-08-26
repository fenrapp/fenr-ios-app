import Foundation
import StarkProtocol

@MainActor
final class BikeBLEPowerModeConfigurationCoordinator {
    private let transport: any BikeBLEPowerModeConfigurationTransporting
    private let eventEmitter: BikeBLEEventEmitter
    private let sessionStore: BLESessionStore
    private var automaticRefreshTask: Task<Void, Never>?
    private var didStartAutomaticRefresh = false
    private var lastReadinessLog = ""

    init(
        transport: any BikeBLEPowerModeConfigurationTransporting,
        eventEmitter: BikeBLEEventEmitter,
        sessionStore: BLESessionStore
    ) {
        self.transport = transport
        self.eventEmitter = eventEmitter
        self.sessionStore = sessionStore
    }

    func startAutomaticRefreshIfNeeded() {
        logReadinessIfChanged()
        guard !didStartAutomaticRefresh, isAutomaticRefreshReady else { return }
        didStartAutomaticRefresh = true
        console("scheduled automatic 4005 refresh")
        automaticRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: Constants.connectionSettleDelay)
            } catch {
                return
            }
            guard isAutomaticRefreshReady else {
                didStartAutomaticRefresh = false
                console("automatic 4005 refresh aborted; session is no longer ready")
                return
            }
            console("automatic 4005 refresh starting; auth=\(sessionStore.authenticationState)")
            await report("Automatic 4005 refresh started")
            do {
                try await refresh()
                await report("Automatic 4005 refresh completed")
            } catch is CancellationError {
                console("automatic 4005 refresh cancelled")
            } catch {
                await report("Automatic 4005 refresh failed: \(error.localizedDescription)")
            }
        }
    }

    func refresh() async throws {
        try await readPowerModeConfigurations()
        try await readTractionControlConfigurations()
    }

    func reset() {
        console("session reset")
        automaticRefreshTask?.cancel()
        automaticRefreshTask = nil
        didStartAutomaticRefresh = false
        lastReadinessLog = ""
    }

    private var isAutomaticRefreshReady: Bool {
        guard sessionStore.hasReportedCompleteTelemetry,
              let characteristic = sessionStore.discoveredCharacteristics[
                BikeSDKConstants.vcuBikeConfigurationUUID
              ]
        else {
            return false
        }
        return characteristic.properties.contains(.read) || characteristic.isNotifying
    }

    private func readPowerModeConfigurations() async throws {
        var receivedMapCount = 0
        var firstFailure: (any Error)?

        for mapIndex in StarkPowerModeConfigurationCommand.mapIndexes {
            try Task.checkCancellation()
            do {
                let request = try StarkPowerModeConfigurationCommand.readPacket(
                    mapIndex: mapIndex
                )
                let response = try await transport.readConfiguration(
                    request: request,
                    operationName: "4005 power mode \(mapIndex) read",
                    allowLiveTelemetrySession: true
                )
                let payload = try StarkPowerModeConfigurationCommand.decodeResponse(
                    response,
                    expectedMapIndex: mapIndex
                )
                receivedMapCount += 1
                await report(
                    "4005 power map \(mapIndex) decoded hp=\(payload.horsepower) "
                        + "regen=\(payload.regenerativeBrakingPercent)%"
                )
                await eventEmitter.send(.telemetry(.powerModeConfiguration(payload)))
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
                let request = try StarkTractionControlConfigurationCommand.readPacket(
                    mapIndex: mapIndex
                )
                let response = try await transport.readConfiguration(
                    request: request,
                    operationName: "4005 traction control \(mapIndex) read",
                    allowLiveTelemetrySession: true
                )
                let payload = try StarkTractionControlConfigurationCommand.decodeResponse(
                    response,
                    expectedMapIndex: mapIndex
                )
                receivedMapCount += 1
                await report(
                    "4005 TC map \(mapIndex) decoded power=\(payload.powerPercent)% "
                        + "braking=\(payload.brakingPercent)%"
                )
                await eventEmitter.send(.telemetry(.tractionControlConfiguration(payload)))
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

    private func logReadinessIfChanged() {
        guard BikePowerModeDebugLog.isEnabled else { return }
        let characteristic = sessionStore.discoveredCharacteristics[
            BikeSDKConstants.vcuBikeConfigurationUUID
        ]
        let message = "readiness auth=\(sessionStore.authenticationState) "
            + "subscriptions=\(sessionStore.hasReportedRequiredSubscriptions) "
            + "liveTelemetry=\(sessionStore.hasReportedCompleteTelemetry) "
            + "4005=\(characteristic != nil) "
            + "notify=\(characteristic?.isNotifying == true) "
            + "read=\(characteristic?.properties.contains(.read) == true) "
            + "refreshing=\(didStartAutomaticRefresh)"
        guard message != lastReadinessLog else { return }
        lastReadinessLog = message
        console(message)
    }

    private func console(_ message: String) {
        BikePowerModeDebugLog.log(message)
    }

    private enum Constants {
        static let connectionSettleDelay = Duration.seconds(1)
        static let interRequestDelay = Duration.milliseconds(150)
    }
}
