import Foundation
import Network

public struct OfflineNetworkState: Sendable {
    public let connected: Bool
    public let wifi: Bool

    public init(connected: Bool, wifi: Bool) {
        self.connected = connected
        self.wifi = wifi
    }
}

public protocol OfflineNetworkMonitoring: Sendable {
    func states() -> AsyncStream<OfflineNetworkState>
}

public struct OfflineNetworkMonitor: OfflineNetworkMonitoring {
    public init() {}

    public func states() -> AsyncStream<OfflineNetworkState> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(OfflineNetworkState(
                    connected: path.status == .satisfied,
                    wifi: path.usesInterfaceType(.wifi) && !path.isConstrained
                ))
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.fenr.offline.network"))
        }
    }
}
