import Foundation

public struct IncomingMapLink: Codable, Equatable, Sendable {
    public let url: URL
    public let receivedAt: Date

    public init(url: URL, receivedAt: Date) {
        self.url = url
        self.receivedAt = receivedAt
    }
}
