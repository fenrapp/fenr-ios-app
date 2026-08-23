@MainActor
public protocol BikeBLETimeoutScheduling: AnyObject {
    func schedule(operation: @escaping @MainActor @Sendable () async -> Void)
    func cancel()
}
