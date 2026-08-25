@testable import BikeSDK
import Foundation
import Testing

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

    @Test("SDK errors expose their useful message through LocalizedError")
    func exposesLocalizedError() {
        let error = BikeSDKError.operationFailed("4005 notifications are unavailable")

        #expect(error.localizedDescription == "4005 notifications are unavailable")
    }
}

private actor ConfigurationTransactionProbe {
    private(set) var maximumConcurrentTransactions = 0
    private(set) var completedIdentifiers: Set<Int> = []
    private var activeTransactions = 0

    func start() {
        activeTransactions += 1
        maximumConcurrentTransactions = max(maximumConcurrentTransactions, activeTransactions)
    }

    func finish(_ identifier: Int) {
        activeTransactions -= 1
        completedIdentifiers.insert(identifier)
    }
}
