import CoreBluetooth

extension CBCharacteristic {
    var hasClientConfigurationDescriptor: Bool {
        descriptors?.contains { $0.uuid == BikeSDKConstants.cccdUUID } ?? false
    }
}
