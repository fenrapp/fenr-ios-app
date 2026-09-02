@testable import BikeSDK
import CoreBluetooth
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("VCU configuration operation controller")
struct BikeBLEVCUConfigurationOperationControllerTests {
    @Test("Buffers an expected response that arrives before the write callback")
    func buffersEarlyResponse() async throws {
        let scheduler = FakeBikeBLETimeoutScheduler()
        let controller = BikeBLEVCUConfigurationOperationController(timeoutScheduler: scheduler)
        let characteristicID = BikeSDKConstants.vcuBikeConfigurationUUID
        let response = Data([1, 8, 0])
        controller.expect(try .init(writeRequest: Data([1, 8, 1, 3, 15, 120, 0, 200, 0])))

        let write = Task { @MainActor in
            try await withCheckedThrowingContinuation { continuation in
                controller.start(
                    uuid: characteristicID,
                    kind: .write,
                    operationName: "test write",
                    continuation: continuation
                )
            } as Data
        }
        #expect(await waitUntil { scheduler.hasPendingOperation })

        #expect(controller.completeRead(uuid: characteristicID, data: response, error: nil))
        #expect(try await write.value == Data())
        #expect(try controller.takeBufferedResponse() == response)
        #expect(!scheduler.hasPendingOperation)
    }

    @Test("A write timeout desynchronizes the controller until reset")
    func recoversFromTimeoutOnlyAfterReset() async {
        let scheduler = FakeBikeBLETimeoutScheduler()
        let controller = BikeBLEVCUConfigurationOperationController(timeoutScheduler: scheduler)
        let characteristicID = BikeSDKConstants.vcuBikeConfigurationUUID
        let write = Task { @MainActor in
            try await withCheckedThrowingContinuation { continuation in
                controller.start(
                    uuid: characteristicID,
                    kind: .write,
                    operationName: "test write",
                    continuation: continuation
                )
            } as Data
        }
        #expect(await waitUntil { scheduler.hasPendingOperation })

        await scheduler.fire()
        await #expect(throws: BikeSDKError.self) { try await write.value }
        #expect(throws: BikeSDKError.self) { try controller.ensureReady() }

        controller.reset()
        #expect(throws: Never.self) { try controller.ensureReady() }
    }
}
