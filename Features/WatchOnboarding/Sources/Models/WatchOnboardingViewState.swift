public struct WatchOnboardingViewState: Equatable, Sendable {
    public var discoveredBikes: [WatchDiscoveredBikeViewData]
    public var debugEvents: [WatchDebugEventViewData]
    public var detail: String
    public var errorMessage: String?
    public var isConnecting: Bool

    public init(
        discoveredBikes: [WatchDiscoveredBikeViewData] = [],
        debugEvents: [WatchDebugEventViewData] = [],
        detail: String = "Searching for nearby bikes",
        errorMessage: String? = nil,
        isConnecting: Bool = false
    ) {
        self.discoveredBikes = discoveredBikes
        self.debugEvents = debugEvents
        self.detail = detail
        self.errorMessage = errorMessage
        self.isConnecting = isConnecting
    }
}
