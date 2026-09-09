import BikeDomain
import BikeSDK

public struct BikeSDKTractionControlMapper: Sendable {
    public init() {}

    func map(_ value: BikeSDKTractionControlSnapshot) -> BikeTractionControlSnapshot {
        .init(mapIndex: value.mapIndex, powerRaw: value.powerRaw, brakingRaw: value.brakingRaw)
    }

    func map(_ value: BikeTractionControlSnapshot) -> BikeSDKTractionControlSnapshot {
        .init(mapIndex: value.mapIndex, powerRaw: value.powerRaw, brakingRaw: value.brakingRaw)
    }

    func map(_ error: BikeSDKTractionControlError) -> BikeTractionControlError {
        switch error {
        case .connectionRecoveryRequired: .connectionRecoveryRequired
        case .unavailable: .unavailable
        case .rejected: .rejected
        case .changed(let actual): .changed(map(actual))
        case .mismatch(let actual): .mismatch(map(actual))
        case .confirmationUnavailable: .confirmationUnavailable
        }
    }
}
