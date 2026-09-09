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

    @Test("Missing initial read permits exactly one requested write and fresh confirmation")
    func missingBaseline() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.tractionReadFailuresRemaining = 1
        let actual = try await apply(makeUserTractionCoordinator(transport))
        #expect(actual == .init(mapIndex: 0, powerRaw: 350, brakingRaw: 0))
        #expect(transport.writePayloads.count == 1)
        #expect(transport.requests == [Data([0, 8, 0]), Data([0, 8, 0])])
    }

    @Test("Readable baseline requires a no-op and confirmation before the requested write")
    func readableBaseline() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        _ = try await apply(makeUserTractionCoordinator(transport))
        #expect(transport.writePayloads.count == 2)
        #expect(transport.writePayloads.first == Data([1, 8, 1, 0, 15, 200, 0, 200, 0]))
        #expect(transport.requests.count == 3)
    }

    @Test("Current requested values confirm without writing")
    func exactValues() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        _ = try await makeUserTractionCoordinator(transport).applyUserTractionControlConfiguration(
            mapIndex: 0, powerTractionPercent: 20, brakingTractionPercent: 20, expected: nil
        )
        #expect(transport.writePayloads.isEmpty)
    }

    @Test("Changed known configuration is returned without writing")
    func staleBaseline() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        await #expect(throws: BikeSDKTractionControlError.changed(.init(mapIndex: 0, powerRaw: 200, brakingRaw: 200))) {
            try await makeUserTractionCoordinator(transport).applyUserTractionControlConfiguration(
                mapIndex: 0, powerTractionPercent: 35, brakingTractionPercent: 0,
                expected: .init(mapIndex: 0, powerRaw: 100, brakingRaw: 0)
            )
        }
        #expect(transport.writePayloads.isEmpty)
    }

    @Test("An unsuccessful no-op never falls through to the requested write")
    func noOpMismatch() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.queuedTractionResponses = [
            Data([2, 8, 0, 0, 200, 0, 200, 0]), Data([2, 8, 0, 0, 100, 0, 200, 0])
        ]
        let expectedError = BikeSDKTractionControlError.mismatch(.init(mapIndex: 0, powerRaw: 100, brakingRaw: 200))
        await #expect(throws: expectedError) {
            try await apply(makeUserTractionCoordinator(transport))
        }
        #expect(transport.writePayloads.count == 1)
    }

    @Test("Unconfirmed writes can be explicitly retried on the same coordinator")
    func retryAfterTimeout() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.tractionReadFailuresRemaining = 2
        let coordinator = makeUserTractionCoordinator(transport)
        await #expect(throws: BikeSDKTractionControlError.confirmationUnavailable) { try await apply(coordinator) }
        #expect(transport.writePayloads.count == 1)
        _ = try await apply(coordinator)
        #expect(transport.writePayloads.count == 1)
    }

    @Test("Both returned fields must match, including the unchanged sibling")
    func siblingMismatch() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.tractionReadFailuresRemaining = 1
        transport.queuedTractionResponses = [Data([2, 8, 0, 0, 94, 1, 10, 0])]
        await #expect(throws: BikeSDKTractionControlError.mismatch(.init(mapIndex: 0, powerRaw: 350, brakingRaw: 10))) {
            try await apply(makeUserTractionCoordinator(transport))
        }
    }

    @Test("Write errors distinguish explicit rejection from an uncertain outcome", arguments: [true, false])
    func writeErrors(rejected: Bool) async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.tractionReadFailuresRemaining = 1
        transport.writeError = rejected
            ? StarkProtocolError.configurationRequestFailed(status: 1)
            : BikeSDKError.operationFailed("Synthetic timeout")
        await #expect(throws: rejected ? BikeSDKTractionControlError.rejected : .confirmationUnavailable) {
            try await apply(makeUserTractionCoordinator(transport))
        }
        #expect(transport.writePayloads.count == 1)
    }

    @Test("A desynchronized transport requires reconnect before retrying")
    func desynchronizedTransport() async throws {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.tractionReadFailuresRemaining = 1
        transport.desynchronizesOnReadFailure = true
        let coordinator = makeUserTractionCoordinator(transport)
        await #expect(throws: BikeSDKTractionControlError.connectionRecoveryRequired) { try await apply(coordinator) }
        #expect(transport.writePayloads.isEmpty)
        await #expect(throws: BikeSDKTractionControlError.connectionRecoveryRequired) { try await apply(coordinator) }
        #expect(transport.writePayloads.isEmpty)
        coordinator.reset()
        transport.isDesynchronized = false
        _ = try await apply(coordinator)
        #expect(transport.writePayloads.count == 2)
    }

    @Test("Cancellation of the initial read never authorizes fallback writing")
    func cancelledRead() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        transport.tractionReadFailuresRemaining = 1
        transport.tractionReadError = CancellationError()
        await #expect(throws: CancellationError.self) { try await apply(makeUserTractionCoordinator(transport)) }
        #expect(transport.writePayloads.isEmpty)
    }

    @Test("A session reset during reading prevents a stale write")
    func staleSession() async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        let coordinator = makeUserTractionCoordinator(transport)
        transport.onTractionRead = { coordinator.reset() }
        await #expect(throws: CancellationError.self) { try await apply(coordinator) }
        #expect(transport.writePayloads.isEmpty)
    }

    @Test("Invalid requested values never reach the transport", arguments: [-1.0, 100.1, 12.5, Double.nan])
    func invalidValue(value: Double) async {
        let transport = FakeBikeBLEPowerModeConfigurationTransport()
        await #expect(throws: (any Error).self) {
            try await makeUserTractionCoordinator(transport).applyUserTractionControlConfiguration(
                mapIndex: 0, powerTractionPercent: value, brakingTractionPercent: 0, expected: nil
            )
        }
        #expect(transport.writePayloads.isEmpty)
    }

    private func apply(
        _ coordinator: BikeBLEPowerModeConfigurationCoordinator
    ) async throws -> BikeSDKTractionControlSnapshot {
        try await coordinator.applyUserTractionControlConfiguration(
            mapIndex: 0, powerTractionPercent: 35, brakingTractionPercent: 0, expected: nil
        )
    }

}
