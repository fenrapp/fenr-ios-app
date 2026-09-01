import Foundation

public protocol BLETraceWriterTaskStarter: Sendable {
    func start(
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never>
}

public struct LiveBLETraceWriterTaskStarter: BLETraceWriterTaskStarter, Sendable {
    public init() {}

    public func start(
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task {
            await operation()
        }
    }
}
