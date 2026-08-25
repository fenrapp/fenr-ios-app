public struct BikeOnboardingViewState: Equatable, Sendable {
    public var step: BikeOnboardingStep
    public var vin: String
    public var connectionDetail: String
    public var connectionPhase: BikeOnboardingConnectionPhase?
    public var isConnecting: Bool
    public var isRequestingBluetoothAccess: Bool
    public var isDiscoveringBikes: Bool
    public var discoveredBikes: [BikeDiscoveryViewData]
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
        discoveredBikes: [BikeDiscoveryViewData] = [],
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
