import Foundation

public protocol StarkPayloadDecoding<Payload>: Sendable {
    associatedtype Payload: StarkPayload

    func decode(_ data: Data) throws -> Payload
}
