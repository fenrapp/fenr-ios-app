import Foundation
import StarkProtocol

public struct BikeSDKIMUSample: Equatable, Sendable {
    public let payload: StarkIMUPayload
    public let observedAt: Date

    public init(payload: StarkIMUPayload, observedAt: Date) {
        self.payload = payload
        self.observedAt = observedAt
    }
}
