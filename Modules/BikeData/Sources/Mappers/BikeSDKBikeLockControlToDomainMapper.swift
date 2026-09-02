import BikeDomain
import BikeSDK

public struct BikeSDKBikeLockControlToDomainMapper: Sendable {
    public init() {}

    func map(_ snapshot: BikeSDKBikeLockControlSnapshot) -> BikeLockControlSnapshot {
        BikeLockControlSnapshot(
            vcuFirmware: snapshot.vcuFirmware,
            isLocked: snapshot.isLocked,
            didPassNoOpWrite: snapshot.didPassNoOpWrite
        )
    }
}
