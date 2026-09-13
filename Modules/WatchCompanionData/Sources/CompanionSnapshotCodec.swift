import Foundation
import WatchCompanionDomain

public struct CompanionSnapshotCodec: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(encoder: JSONEncoder, decoder: JSONDecoder) {
        self.encoder = encoder
        self.decoder = decoder
    }

    public func encode(_ snapshot: CompanionSnapshot) throws -> Data {
        try encoder.encode(snapshot)
    }

    public func decode(_ data: Data) throws -> CompanionSnapshot {
        guard data.count <= 16_384 else { throw CodecError.invalidPayload }
        let snapshot = try decoder.decode(CompanionSnapshot.self, from: data)
        guard snapshot.version == 1,
              snapshot.batteryPercent.map({ (0...100).contains($0) }) ?? true,
              snapshot.mapIndex.map({ (1...5).contains($0) }) ?? true
        else { throw CodecError.invalidPayload }
        return snapshot
    }

    public func accepts(_ incoming: CompanionSnapshot, after current: CompanionSnapshot?) -> Bool {
        current.map { incoming.generatedAt > $0.generatedAt } ?? true
    }

    private enum CodecError: Error {
        case invalidPayload
    }
}
