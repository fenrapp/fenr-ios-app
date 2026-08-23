import Foundation

public extension StarkUUIDs {
    static let liveSpeed = StarkUUIDFactory.proprietary("00002001")
    static let liveThrottle = StarkUUIDFactory.proprietary("00002002")
    static let liveIMU = StarkUUIDFactory.proprietary("00002003")
    static let liveMap = StarkUUIDFactory.proprietary("00002004")
    static let liveTotals = StarkUUIDFactory.proprietary("00002005")
    static let liveEstimation = StarkUUIDFactory.proprietary("00002006")
    static let liveRacing = StarkUUIDFactory.proprietary("00002007")
    static let liveConfiguration = StarkUUIDFactory.proprietary("00002008")
    static let liveTelemetryTLV = StarkUUIDFactory.proprietary("00002100")
    static let liveTelemetryTLVConfiguration = StarkUUIDFactory.proprietary("00002101")
}
