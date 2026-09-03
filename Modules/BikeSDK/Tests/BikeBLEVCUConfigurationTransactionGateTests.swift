@testable import BikeSDK
import Foundation
import Testing
import TestSupport

@Suite("VCU 4005 transaction gate")
struct BikeBLEVCUConfigurationTransactionGateTests {
    @Test("Serializes concurrent configuration transactions")
    func serializesTransactions() async {
        let gate = BikeBLEVCUConfigurationTransactionGate()
        let probe = ConfigurationTransactionProbe()

        await withTaskGroup(of: Void.self) { group in
            for identifier in 0 ..< 10 {
                group.addTask {
                    await gate.acquire()
                    await probe.start()
                    await Task.yield()
                    await probe.finish(identifier)
                    await gate.release()
                }
            }
        }

        #expect(await probe.maximumConcurrentTransactions == 1)
        #expect(await probe.completedIdentifiers.count == 10)
    }

    @Test("Cancellation removes a queued transaction while preserving FIFO and reuse")
    func cancellationRemovesQueuedTransaction() async throws {
        let gate = BikeBLEVCUConfigurationTransactionGate()
        let probe = ConfigurationTransactionProbe()

        await gate.acquire()

        let cancelledWaiter = Task {
            try await gate.acquireCancellable()
            await probe.recordEntry("cancelled")
            await gate.release()
        }
        #expect(await waitUntil { await gate.pendingWaiterCount == 1 })

        let firstSurvivor = Task {
            try await gate.acquireCancellable()
            await probe.recordEntry("first survivor")
            await gate.release()
        }
        #expect(await waitUntil { await gate.pendingWaiterCount == 2 })

        let secondSurvivor = Task {
            try await gate.acquireCancellable()
            await probe.recordEntry("second survivor")
            await gate.release()
        }
        #expect(await waitUntil { await gate.pendingWaiterCount == 3 })

        cancelledWaiter.cancel()
        await #expect(throws: CancellationError.self) {
            try await cancelledWaiter.value
        }
        #expect(await waitUntil { await gate.pendingWaiterCount == 2 })

        await gate.release()
        try await firstSurvivor.value
        try await secondSurvivor.value

        try await gate.acquireCancellable()
        await probe.recordEntry("reused")
        await gate.release()

        #expect(await probe.enteredTransactions == [
            "first survivor",
            "second survivor",
            "reused"
        ])
    }
}

@Suite("VCU 4005 response matching")
struct BikeBLEVCUConfigurationResponseMatchingTests {
    @Test("Matches the requested type and map for read or notification responses")
    func matchesExpectedResponse() throws {
        let expected = try BikeBLEVCUConfigurationExpectedResponse(request: Data([0, 8, 3]))

        #expect(expected.matches(Data([0, 8, 0, 3, 10, 0, 20, 0])))
        #expect(expected.matches(Data([0, 8, 2])))
        #expect(!expected.matches(Data([0, 0, 0, 3, 10, 0, 20, 0])))
        #expect(!expected.matches(Data([0, 8, 0, 2, 10, 0, 20, 0])))
    }

    @Test("Rejects malformed write requests")
    func rejectsMalformedRequest() {
        #expect(throws: BikeSDKError.operationFailed("Invalid 4005 read request")) {
            try BikeBLEVCUConfigurationExpectedResponse(request: Data([1, 8, 0]))
        }
    }

    @Test("Matches only acknowledged write responses for ordinary configuration types")
    func matchesExpectedWriteResponse() throws {
        let expected = try BikeBLEVCUConfigurationExpectedResponse(
            writeRequest: Data([1, 8, 1, 3, 15, 120, 0, 200, 0])
        )

        #expect(expected.matches(Data([1, 8, 0])))
        #expect(expected.matches(Data([1, 8, 7])))
        #expect(!expected.matches(Data([2, 8, 0, 3, 120, 0, 200, 0])))
        #expect(!expected.matches(Data([1, 0, 0])))
        #expect(!expected.matches(Data([2, 0, 0])))
    }

    @Test("Matches the captured Bike Lock no-op response envelope")
    func matchesBikeLockWriteResponse() throws {
        let expected = try BikeBLEVCUConfigurationExpectedResponse(
            writeRequest: Data([1, 5, 0x83, 0, 1, 0, 0])
        )

        #expect(expected.matches(Data([2, 5, 0, 0, 1, 0, 0])))
    }

    @Test("SDK errors expose their useful message through LocalizedError")
    func exposesLocalizedError() {
        let error = BikeSDKError.operationFailed("4005 notifications are unavailable")

        #expect(error.localizedDescription == "4005 notifications are unavailable")
    }
}

@MainActor
@Suite("VCU 4005 notification readiness")
struct BikeBLEConfigurationReadinessWaiterTests {
    @Test("Waits for the configuration notification without issuing a BLE operation")
    func waitsUntilReady() async throws {
        let waiter = BikeBLEConfigurationReadinessWaiter(
            checkInterval: .milliseconds(1),
            maximumCheckCount: 5
        )
        var checks = 0

        try await waiter.waitUntilReady {
            checks += 1
            return checks == 3
        }

        #expect(checks == 3)
    }

    @Test("Fails after the bounded readiness window")
    func timesOut() async {
        let waiter = BikeBLEConfigurationReadinessWaiter(
            checkInterval: .milliseconds(1),
            maximumCheckCount: 2
        )

        await #expect(throws: BikeSDKError.self) {
            try await waiter.waitUntilReady { false }
        }
    }
}

private actor ConfigurationTransactionProbe {
    private(set) var maximumConcurrentTransactions = 0
    private(set) var completedIdentifiers: Set<Int> = []
    private(set) var enteredTransactions: [String] = []
    private var activeTransactions = 0

    func start() {
        activeTransactions += 1
        maximumConcurrentTransactions = max(maximumConcurrentTransactions, activeTransactions)
    }

    func finish(_ identifier: Int) {
        activeTransactions -= 1
        completedIdentifiers.insert(identifier)
    }

    func recordEntry(_ transaction: String) {
        enteredTransactions.append(transaction)
    }
}
