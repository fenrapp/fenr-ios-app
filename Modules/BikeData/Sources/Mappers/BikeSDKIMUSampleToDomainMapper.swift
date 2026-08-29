import BikeDomain
import BikeSDK

public struct BikeSDKIMUSampleToDomainMapper: Sendable {
    public init() {}

    public func map(_ sample: BikeSDKIMUSample) -> BikeIMUSample {
        let payload = sample.payload
        return BikeIMUSample(
            accelerationRaw: .init(
                x: Double(payload.accelerationXRaw),
                y: Double(payload.accelerationYRaw),
                z: Double(payload.accelerationZRaw)
            ),
            gyroscopeRaw: .init(
                x: Double(payload.gyroscopeXRaw),
                y: Double(payload.gyroscopeYRaw),
                z: Double(payload.gyroscopeZRaw)
            ),
            observedAt: sample.observedAt
        )
    }
}
