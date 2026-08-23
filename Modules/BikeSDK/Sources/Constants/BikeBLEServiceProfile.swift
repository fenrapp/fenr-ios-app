import CoreBluetooth

struct BikeBLEServiceProfile {
    let serviceUUID: CBUUID
    let characteristicUUIDs: [CBUUID]
}
