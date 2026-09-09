import CoreBluetooth
import Foundation

@MainActor
struct BikeBLEConfigurationReadinessWaiter {
    private let checkInterval: Duration
    private let maximumCheckCount: Int

    init(
        checkInterval: Duration,
        maximumCheckCount: Int
    ) {
        self.checkInterval = checkInterval
        self.maximumCheckCount = maximumCheckCount
    }

    func waitUntilReady(_ isReady: @escaping @MainActor () -> Bool) async throws {
        guard !isReady() else { return }
        for _ in 0 ..< maximumCheckCount {
            try await Task.sleep(for: checkInterval)
            try Task.checkCancellation()
            if isReady() { return }
        }
        throw BikeSDKError.operationFailed(
            "VCU configuration 4005 notifications did not become ready"
        )
    }
}

extension BikeBLEVCUConfigurationTransport {
    func ensureReady() throws {
        try checkTransactionGeneration()
        try operationController.ensureReady()
    }

    func waitForConfigurationNotificationsIfNeeded(_ characteristic: CBCharacteristic) async throws {
        guard !characteristic.properties.contains(.read) else { return }
        try await configurationReadinessWaiter.waitUntilReady {
            characteristic.isNotifying
                || self.sessionStore.subscribedCharacteristics.contains(characteristic.uuid)
        }
    }
}
