import CoreBluetooth

@MainActor
struct BikeBLENotificationPreparer {
    private let eventEmitter: BikeBLEEventEmitter
    private let peripheralOperations: BikeBLEPeripheralOperations

    init(
        eventEmitter: BikeBLEEventEmitter,
        peripheralOperations: BikeBLEPeripheralOperations
    ) {
        self.eventEmitter = eventEmitter
        self.peripheralOperations = peripheralOperations
    }

    func prepare(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
            await eventEmitter.send(.error(.operationFailed(
                "\(BikeSDKText.telemetryNotifyUnavailable): \(characteristic.uuid.uuidString)"
            )))
            return
        }
        await peripheralOperations.discoverDescriptors(
            characteristic: characteristic,
            peripheral: peripheral
        )
    }
}
