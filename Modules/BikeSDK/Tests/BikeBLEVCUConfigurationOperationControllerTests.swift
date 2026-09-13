@testable import BikeSDK
import CoreBluetooth
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("VCU configuration operation controller")
struct BikeBLEVCUConfigurationOperationControllerTests {
    @Test("Buffers an expected response that arrives before the write callback", arguments: [
        Data([1, 8, 0]), Data([2, 8, 0, 3, 120, 0, 200, 0])
    ])
    func buffersEarlyResponse(response: Data) async throws {
        let scheduler = FakeBikeBLETimeoutScheduler()
        let controller = BikeBLEVCUConfigurationOperationController(timeoutScheduler: scheduler)
        let characteristicID = BikeSDKConstants.vcuBikeConfigurationUUID
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
        #expect(scheduler.hasPendingOperation)
        controller.completeWrite(uuid: characteristicID, error: nil)
        #expect(try await write.value == Data())
        #expect(try controller.takeBufferedResponse() == response)
        #expect(!scheduler.hasPendingOperation)
    }

    @Test("Traction values received after the write callback finish the wait without desynchronizing")
    func completesTractionNotificationResponse() async throws {
        let scheduler = FakeBikeBLETimeoutScheduler()
        let controller = BikeBLEVCUConfigurationOperationController(timeoutScheduler: scheduler)
        let characteristicID = BikeSDKConstants.vcuBikeConfigurationUUID
        let response = Data([2, 8, 0, 3, 120, 0, 200, 0])
        controller.expect(try .init(writeRequest: Data([1, 8, 1, 3, 15, 120, 0, 200, 0])))
        let pending = Task { @MainActor in
            try await withCheckedThrowingContinuation { continuation in
                controller.start(
                    uuid: characteristicID, kind: .configurationResponse,
                    operationName: "traction write response", continuation: continuation
                )
            } as Data
        }
        #expect(await waitUntil { scheduler.hasPendingOperation })
        #expect(!controller.completeRead(
            uuid: characteristicID, data: Data([2, 8, 0, 2, 120, 0, 200, 0]), error: nil
        ))
        #expect(scheduler.hasPendingOperation)
        #expect(controller.completeRead(uuid: characteristicID, data: response, error: nil))
        #expect(try await pending.value == response)
        #expect(!scheduler.hasPendingOperation)
        #expect(throws: Never.self) { try controller.ensureReady() }
    }

    @Test("Timeouts require reset before another operation", arguments: [
        BikeBLEVCUConfigurationOperationKind.write, .read, .configurationResponse
    ])
    func recoversFromTimeoutOnlyAfterReset(kind: BikeBLEVCUConfigurationOperationKind) async {
        let scheduler = FakeBikeBLETimeoutScheduler()
        let controller = BikeBLEVCUConfigurationOperationController(timeoutScheduler: scheduler)
        let characteristicID = BikeSDKConstants.vcuBikeConfigurationUUID
        let write = Task { @MainActor in
            try await withCheckedThrowingContinuation { continuation in
                controller.start(
                    uuid: characteristicID,
                    kind: kind,
                    operationName: "test operation",
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
