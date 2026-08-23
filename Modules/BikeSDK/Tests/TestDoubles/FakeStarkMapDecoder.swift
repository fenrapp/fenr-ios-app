import Foundation
import StarkProtocol

struct FakeStarkMapDecoder: StarkPayloadDecoding {
    let payload: StarkMapPayload

    func decode(_ data: Data) throws -> StarkMapPayload {
        payload
    }
}
