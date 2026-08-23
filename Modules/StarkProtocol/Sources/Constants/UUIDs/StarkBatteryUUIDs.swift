import Foundation

public extension StarkUUIDs {
    static let batteryStatus = StarkUUIDFactory.proprietary("00006001")
    static let batteryFirmwareVersion = StarkUUIDFactory.proprietary("00006002")
    static let batteryParams = StarkUUIDFactory.proprietary("00006003")
    static let batterySOC = StarkUUIDFactory.proprietary("00006004")
    static let batteryTemperatures = StarkUUIDFactory.proprietary("00006005")
    static let batteryDCBus = StarkUUIDFactory.proprietary("00006006")
    static let batteryCellVoltages = StarkUUIDFactory.proprietary("00006007")
    static let batteryBalancing = StarkUUIDFactory.proprietary("00006008")
    static let batterySignals = StarkUUIDFactory.proprietary("00006009")
    static let batteryConfiguration = StarkUUIDFactory.proprietary("0000600A")
    static let batteryTelemetryTLV = StarkUUIDFactory.proprietary("00006100")
    static let batteryTelemetryTLVConfiguration = StarkUUIDFactory.proprietary("00006101")
}
