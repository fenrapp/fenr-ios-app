import CoreBluetooth

@MainActor
struct BikeBLENotificationPreparer {
    private let eventEmitter: BikeBLEEventEmitter

    init(eventEmitter: BikeBLEEventEmitter) {
        self.eventEmitter = eventEmitter
    }

    func prepare(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
            await eventEmitter.send(.error(.operationFailed(
                "\(BikeSDKText.telemetryNotifyUnavailable): \(characteristic.uuid.uuidString)"
            )))
            return
        }
        peripheral.discoverDescriptors(for: characteristic)
    }
}
