import BikeDomain

public enum BikeOnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case preparation
    case identify
    case connect
}

public struct BikeOnboardingViewState: Equatable, Sendable {
    public var step: BikeOnboardingStep
    public var vin: String
    public var connectionDetail: String
    public var isConnecting: Bool
    public var isDiscoveringBikes: Bool
    public var discoveredBikes: [DiscoveredBike]
    public var canContinue: Bool
    public var errorMessage: String?

    public init(
        step: BikeOnboardingStep = .welcome,
        vin: String = "",
        connectionDetail: String = "Ready to connect",
        isConnecting: Bool = false,
        isDiscoveringBikes: Bool = false,
        discoveredBikes: [DiscoveredBike] = [],
        canContinue: Bool = true,
        errorMessage: String? = nil
    ) {
        self.step = step
        self.vin = vin
        self.connectionDetail = connectionDetail
        self.isConnecting = isConnecting
        self.isDiscoveringBikes = isDiscoveringBikes
        self.discoveredBikes = discoveredBikes
        self.canContinue = canContinue
        self.errorMessage = errorMessage
    }
}
