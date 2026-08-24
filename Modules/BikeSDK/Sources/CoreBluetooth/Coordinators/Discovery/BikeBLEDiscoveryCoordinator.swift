import CoreBluetooth
import StarkProtocol

@MainActor
public struct BikeBLEDiscoveryCoordinator {
    private let eventEmitter: BikeBLEEventEmitter
    private let securityCoordinator: BikeBLESecurityCoordinator
    private let notificationCoordinator: BikeBLENotificationCoordinator

    public init(
        eventEmitter: BikeBLEEventEmitter,
        securityCoordinator: BikeBLESecurityCoordinator,
        notificationCoordinator: BikeBLENotificationCoordinator
    ) {
        self.eventEmitter = eventEmitter
        self.securityCoordinator = securityCoordinator
        self.notificationCoordinator = notificationCoordinator
    }

    public func didDiscoverServices(peripheral: CBPeripheral, error: Error?) async {
        if let error {
            let message = "Service discovery failed: \(error.localizedDescription)"
            await eventEmitter.send(.error(.operationFailed(message)))
            return
        }
        let services = peripheral.services ?? []
        for service in services {
            await eventEmitter.send(.debug(.init(
                title: BikeSDKText.serviceTitle,
                detail: service.uuid.uuidString
            )))
        }
        let discoveredServiceUUIDs = Set(services.map(\.uuid))
        let missingServiceUUIDs = BikeSDKConstants.requiredServiceUUIDs.filter {
            !discoveredServiceUUIDs.contains($0)
        }
        if !missingServiceUUIDs.isEmpty {
            let missing = missingServiceUUIDs.map(\.uuidString).joined(separator: ",")
            await eventEmitter.send(.error(.operationFailed(
                "\(BikeSDKText.requiredServicesMissing): \(missing)"
            )))
        }
        guard services.contains(where: { $0.uuid == BikeSDKConstants.bikeServiceUUID }) else {
            await eventEmitter.send(.error(.operationFailed(BikeSDKText.securityServiceMissing)))
            return
        }
        for service in services where BikeSDKConstants.serviceUUIDs.contains(service.uuid) {
            peripheral.discoverCharacteristics(
                BikeSDKConstants.characteristicUUIDs(for: service.uuid),
                for: service
            )
        }
    }

    public func didDiscoverCharacteristics(peripheral: CBPeripheral, service: CBService, error: Error?) async {
        if let error {
            let message = "Characteristic discovery failed: \(error.localizedDescription)"
            await eventEmitter.send(.error(.operationFailed(message)))
            return
        }

        let characteristics = service.characteristics ?? []
        let discoveredUUIDs = Set(characteristics.map(\.uuid))
        let missingUUIDs = BikeSDKConstants.requiredCharacteristicUUIDs(for: service.uuid).filter {
            !discoveredUUIDs.contains($0)
        }
        if !missingUUIDs.isEmpty {
            let missing = missingUUIDs.map(\.uuidString).joined(separator: ",")
            await eventEmitter.send(.error(.operationFailed(
                "\(BikeSDKText.requiredCharacteristicsMissing): \(missing)"
            )))
        }

        if service.uuid == BikeSDKConstants.bikeServiceUUID,
           !characteristics.contains(where: { securityCoordinator.handles($0) }) {
            await eventEmitter.send(.error(.operationFailed(BikeSDKText.securityCharacteristicMissing)))
            return
        }

        for characteristic in characteristics where shouldHandle(characteristic) {
            if securityCoordinator.handles(characteristic) {
                await securityCoordinator.discovered(characteristic: characteristic, peripheral: peripheral)
            } else {
                await notificationCoordinator.discovered(characteristic: characteristic, peripheral: peripheral)
            }
        }
    }

    private func shouldHandle(_ characteristic: CBCharacteristic) -> Bool {
        BikeSDKConstants.characteristicUUIDs.contains(characteristic.uuid)
    }
}
