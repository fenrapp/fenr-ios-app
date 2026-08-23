import Foundation

public extension StarkUUIDs {
    static let bikeSecurity = StarkUUIDFactory.proprietary("00001001")
    static let bikeStatus = StarkUUIDFactory.proprietary("00001002")
    static let vin = StarkUUIDFactory.proprietary("00001003")
    static let bikeVersions = StarkUUIDFactory.proprietary("00001005")
    static let phoneSOC = StarkUUIDFactory.proprietary("00001006")
    static let bikeTelemetryTLV = StarkUUIDFactory.proprietary("00001100")
    static let bikeTelemetryTLVConfiguration = StarkUUIDFactory.proprietary("00001101")
    static let bikeBatteryLevel = StarkUUIDFactory.standard("00002a19-0000-1000-8000-00805f9b34fb")
}
