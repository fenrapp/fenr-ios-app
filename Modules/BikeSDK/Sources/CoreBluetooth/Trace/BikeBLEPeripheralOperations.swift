import BLETraceDomain
import CoreBluetooth
import Foundation

@MainActor
struct BikeBLEPeripheralOperations {
    private let traceEmitter: BikeBLETraceEmitter

    init(traceEmitter: BikeBLETraceEmitter) {
        self.traceEmitter = traceEmitter
    }

    func discoverServices(_ serviceUUIDs: [CBUUID], peripheral: CBPeripheral) async {
        await traceEmitter.record(
            category: "gatt",
            operation: .discoverServicesRequested,
            direction: .outbound,
            detail: serviceUUIDs.map(\.uuidString).joined(separator: ",")
        )
        peripheral.discoverServices(serviceUUIDs)
    }

    func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID],
        service: CBService,
        peripheral: CBPeripheral
    ) async {
        await traceEmitter.record(
            category: "gatt",
            operation: .discoverCharacteristicsRequested,
            direction: .outbound,
            serviceUUID: service.uuid,
            detail: characteristicUUIDs.map(\.uuidString).joined(separator: ",")
        )
        peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
    }

    func discoverDescriptors(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        await traceEmitter.record(
            category: "gatt",
            operation: .discoverDescriptorsRequested,
            direction: .outbound,
            serviceUUID: characteristic.service?.uuid,
            characteristicUUID: characteristic.uuid
        )
        peripheral.discoverDescriptors(for: characteristic)
    }

    func setNotifyValue(_ enabled: Bool, characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        await traceEmitter.record(
            category: "gatt",
            operation: .notificationStateRequested,
            direction: .outbound,
            serviceUUID: characteristic.service?.uuid,
            characteristicUUID: characteristic.uuid,
            detail: enabled ? "enabled" : "disabled"
        )
        peripheral.setNotifyValue(enabled, for: characteristic)
    }

    func readValue(characteristic: CBCharacteristic, peripheral: CBPeripheral) async {
        await prepareReadValue(characteristic: characteristic)
        peripheral.readValue(for: characteristic)
    }

    func prepareReadValue(characteristic: CBCharacteristic) async {
        await traceEmitter.recordReadRequested(characteristic: characteristic)
    }

    func writeValue(
        _ data: Data,
        characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType,
        peripheral: CBPeripheral
    ) async {
        await prepareWriteValue(data, characteristic: characteristic, type: type)
        peripheral.writeValue(data, for: characteristic, type: type)
    }

    func prepareWriteValue(
        _ data: Data,
        characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType
    ) async {
        await traceEmitter.record(
            category: "gatt",
            operation: .writeRequested,
            direction: .outbound,
            serviceUUID: characteristic.service?.uuid,
            characteristicUUID: characteristic.uuid,
            characteristicProperties: characteristic.properties.protocolDescription,
            data: data,
            detail: type == .withResponse ? "with_response" : "without_response"
        )
    }

    func readRSSI(peripheral: CBPeripheral) async {
        await traceEmitter.record(
            category: "link",
            operation: .rssiRequested,
            direction: .outbound
        )
        peripheral.readRSSI()
    }
}
