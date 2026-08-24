import BikeDomain

public enum BikeOnboardingStep: Int, CaseIterable, Hashable, Sendable {
    case welcome
    case preparation
    case identify
    case connect
}

public enum BikeOnboardingConnectionPhase: Int, CaseIterable, Sendable {
    case scanning
    case connecting
    case discovering
    case authenticating
    case subscribing
}

public struct BikeOnboardingViewState: Equatable, Sendable {
    public var step: BikeOnboardingStep
    public var vin: String
    public var connectionDetail: String
    public var connectionPhase: BikeOnboardingConnectionPhase?
    public var isConnecting: Bool
    public var isRequestingBluetoothAccess: Bool
    public var isDiscoveringBikes: Bool
    public var discoveredBikes: [DiscoveredBike]
    public var canContinue: Bool
    public var showsBluetoothSettingsButton: Bool
    public var errorMessage: String?

    public init(
        step: BikeOnboardingStep = .welcome,
        vin: String = "",
        connectionDetail: String = "Ready to connect",
        connectionPhase: BikeOnboardingConnectionPhase? = nil,
        isConnecting: Bool = false,
        isRequestingBluetoothAccess: Bool = false,
        isDiscoveringBikes: Bool = false,
        discoveredBikes: [DiscoveredBike] = [],
        canContinue: Bool = true,
        showsBluetoothSettingsButton: Bool = false,
        errorMessage: String? = nil
    ) {
        self.step = step
        self.vin = vin
        self.connectionDetail = connectionDetail
        self.connectionPhase = connectionPhase
        self.isConnecting = isConnecting
        self.isRequestingBluetoothAccess = isRequestingBluetoothAccess
        self.isDiscoveringBikes = isDiscoveringBikes
        self.discoveredBikes = discoveredBikes
        self.canContinue = canContinue
        self.showsBluetoothSettingsButton = showsBluetoothSettingsButton
        self.errorMessage = errorMessage
    }
}
