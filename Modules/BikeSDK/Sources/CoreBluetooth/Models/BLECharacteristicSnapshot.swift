import Foundation

public struct BLECharacteristicSnapshot: Equatable, Sendable {
    public let uuid: UUID
    public let canRead: Bool
    public let canNotify: Bool
    public let isNotifying: Bool

    public init(uuid: UUID, canRead: Bool, canNotify: Bool, isNotifying: Bool) {
        self.uuid = uuid
        self.canRead = canRead
        self.canNotify = canNotify
        self.isNotifying = isNotifying
    }
}
