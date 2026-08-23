import Foundation

public protocol BikeBLEReconnectDelaying: Sendable {
    func wait(for duration: Duration) async throws
}

public struct BikeBLEReconnectDelay: BikeBLEReconnectDelaying {
    public init() {}

    public func wait(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
