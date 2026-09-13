@testable import BikeSDK
import Foundation
import StarkProtocol
import Testing

@MainActor
@Suite("User-initiated traction control")
struct BikeBLEUserTractionControlTests {
    @Test("Firmware checks are read-only", arguments: ["1.10.0", "1.10.1", "1.12.0"])
    func firmwareCompatibility(version: String) async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.versionData = Data(version.utf8)
        let coordinator = makeUserTractionCoordinator(transport)
        let compatibility = try await coordinator.readTractionControlFirmwareCompatibility()
        #expect(compatibility.isCompatible == (version != "1.10.0"))
        #expect(transport.requests.isEmpty)
        #expect(transport.writePayloads.isEmpty)
    }

    @Test("Unsupported or unknown firmware cannot write", arguments: ["1.10.0", "unknown"])
    func unsupportedFirmware(version: String) async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.versionData = Data(version.utf8)
        await #expect(throws: BikeSDKTractionControlError.unavailable) {
            try await apply(makeUserTractionCoordinator(transport))
        }
        #expect(transport.requests.isEmpty)
        #expect(transport.writePayloads.isEmpty)
    }

    @Test("A commit checks firmware, writes both requested values once, then reads confirmation")
    func directWrite() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let actual = try await apply(makeUserTractionCoordinator(transport))
        #expect(actual == .init(mapIndex: 0, powerRaw: 350, brakingRaw: 0))
        #expect(transport.operations == [
            .versions,
            .configurationWrite(Data([1, 8, 1, 0, 15, 94, 1, 0, 0])),
            .configurationRead(Data([0, 8, 0]))
        ])
    }

    @Test("An explicit unchanged commit still writes and confirms without a baseline read")
    func exactValues() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let actual = try await makeUserTractionCoordinator(transport).applyUserTractionControlConfiguration(
            mapIndex: 0, powerTractionPercent: 20, brakingTractionPercent: 20
        )
        #expect(actual == .init(mapIndex: 0, powerRaw: 200, brakingRaw: 200))
        #expect(transport.writePayloads.count == 1)
        #expect(transport.requests.count == 1)
    }

    @Test("A write that the bike ignores is not reported as applied")
    func ignoredWrite() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.ignoresTractionWrites = true
        let error = BikeSDKTractionControlError.mismatch(.init(mapIndex: 0, powerRaw: 200, brakingRaw: 200))
        await #expect(throws: error) {
            try await apply(makeUserTractionCoordinator(transport))
        }
        #expect(transport.writePayloads.count == 1)
    }

    @Test("An unavailable confirmation permits a new explicit commit while the transport remains ready")
    func retryAfterReadFailure() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.tractionReadFailuresRemaining = 1
        let coordinator = makeUserTractionCoordinator(transport)
        await #expect(throws: BikeSDKTractionControlError.confirmationUnavailable) { try await apply(coordinator) }
        #expect(transport.writePayloads.count == 1)
        _ = try await apply(coordinator)
        #expect(transport.writePayloads.count == 2)
    }

    @Test("Both returned fields must match exactly", arguments: [
        BikeSDKTractionControlSnapshot(mapIndex: 0, powerRaw: 350, brakingRaw: 1),
        BikeSDKTractionControlSnapshot(mapIndex: 0, powerRaw: 349, brakingRaw: 0)
    ])
    func returnedValuesMismatch(actual: BikeSDKTractionControlSnapshot) async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.queuedTractionResponses = [Data([
            2, 8, 0, 0,
            UInt8(truncatingIfNeeded: actual.powerRaw), UInt8(truncatingIfNeeded: actual.powerRaw >> 8),
            UInt8(truncatingIfNeeded: actual.brakingRaw), UInt8(truncatingIfNeeded: actual.brakingRaw >> 8)
        ])]
        await #expect(throws: BikeSDKTractionControlError.mismatch(actual)) {
            try await apply(makeUserTractionCoordinator(transport))
        }
    }

    @Test("Write errors distinguish rejection from an uncertain outcome", arguments: [true, false])
    func writeErrors(rejected: Bool) async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.writeError = rejected
            ? StarkProtocolError.configurationRequestFailed(status: 1)
            : BikeSDKError.operationFailed("Synthetic write failure")
        await #expect(throws: rejected ? BikeSDKTractionControlError.rejected : .confirmationUnavailable) {
            try await apply(makeUserTractionCoordinator(transport))
        }
        #expect(transport.writePayloads.count == 1)
        #expect(transport.requests.isEmpty)
    }

    @Test("A desynchronized confirmation requires reconnect before another write")
    func desynchronizedTransport() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.tractionReadFailuresRemaining = 1
        transport.desynchronizesOnReadFailure = true
        let coordinator = makeUserTractionCoordinator(transport)
        await #expect(throws: BikeSDKTractionControlError.connectionRecoveryRequired) { try await apply(coordinator) }
        #expect(transport.writePayloads.count == 1)
        await #expect(throws: BikeSDKTractionControlError.connectionRecoveryRequired) { try await apply(coordinator) }
        #expect(transport.writePayloads.count == 1)
        coordinator.reset()
        transport.isDesynchronized = false
        _ = try await apply(coordinator)
        #expect(transport.writePayloads.count == 2)
    }

    @Test("Cancellation while writing never falls through to confirmation")
    func cancelledWrite() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.writeError = CancellationError()
        await #expect(throws: CancellationError.self) { try await apply(makeUserTractionCoordinator(transport)) }
        #expect(transport.writePayloads.count == 1)
        #expect(transport.requests.isEmpty)
    }

    @Test("A session reset during the firmware check prevents a stale write")
    func staleFirmwareSession() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeUserTractionCoordinator(transport)
        transport.onVersions = { coordinator.reset() }
        await #expect(throws: CancellationError.self) { try await apply(coordinator) }
        #expect(transport.writePayloads.isEmpty)
        #expect(transport.requests.isEmpty)
    }

    @Test("A session reset during confirmation cannot report a stale success")
    func staleConfirmationSession() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeUserTractionCoordinator(transport)
        transport.onTractionRead = { coordinator.reset() }
        await #expect(throws: CancellationError.self) { try await apply(coordinator) }
        #expect(transport.writePayloads.count == 1)
    }

    @Test("Invalid requested values never reach the transport", arguments: [-1.0, 100.1, 12.5, Double.nan])
    func invalidValue(value: Double) async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        await #expect(throws: (any Error).self) {
            try await makeUserTractionCoordinator(transport).applyUserTractionControlConfiguration(
                mapIndex: 0, powerTractionPercent: value, brakingTractionPercent: 0
            )
        }
        #expect(transport.operations.isEmpty)
    }

    private func apply(
        _ coordinator: BikeBLEPowerModeConfigurationCoordinator
    ) async throws -> BikeSDKTractionControlSnapshot {
        try await coordinator.applyUserTractionControlConfiguration(
            mapIndex: 0, powerTractionPercent: 35, brakingTractionPercent: 0
        )
    }
}
