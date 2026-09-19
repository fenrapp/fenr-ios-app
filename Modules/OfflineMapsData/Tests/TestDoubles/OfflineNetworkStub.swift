import OfflineMapsData

struct OfflineNetworkStub: OfflineNetworkMonitoring {
    let stream: AsyncStream<OfflineNetworkState>
    let continuation: AsyncStream<OfflineNetworkState>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    func states() -> AsyncStream<OfflineNetworkState> { stream }
    func send(connected: Bool = true, wifi: Bool = true) {
        continuation.yield(OfflineNetworkState(connected: connected, wifi: wifi))
    }
}
