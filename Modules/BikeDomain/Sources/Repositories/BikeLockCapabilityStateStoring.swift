@MainActor
public protocol BikeLockCapabilityStateStoring: AnyObject {
    var currentState: BikeLockCapabilityState { get }

    func update(_ state: BikeLockCapabilityState)
    func observe() -> AsyncStream<BikeLockCapabilityState>
}
