public struct BikeOnboardingViewState: Equatable, Sendable {
    public var formattedVIN: String { BikeDiscoveryViewData.formatVIN(vin) }
    public var accessibilityVIN: String { BikeDiscoveryViewData.formatAccessibleVIN(vin) }

    public var step: BikeOnboardingStep
    public var vin: String
    public var pairingPIN: String
    public var selectedBikeTitle: String
    public var connectionState: BikeOnboardingConnectionState
    public var discoveredBikes: [BikeDiscoveryViewData]
    public var bluetoothState: BikeOnboardingBluetoothState
    public var discoveryState: BikeOnboardingDiscoveryState
    public var isRequestingBluetoothAccess: Bool
    public var isDiscoveringBikes: Bool
    public var didCopyPIN: Bool

    public init(
        step: BikeOnboardingStep = .welcome,
        vin: String = "",
        pairingPIN: String = "",
        selectedBikeTitle: String? = nil,
        connectionState: BikeOnboardingConnectionState = .inProgress(.finding),
        discoveredBikes: [BikeDiscoveryViewData] = [],
        bluetoothState: BikeOnboardingBluetoothState = .preparation,
        discoveryState: BikeOnboardingDiscoveryState = .scanning,
        isRequestingBluetoothAccess: Bool = false,
        isDiscoveringBikes: Bool = false,
        didCopyPIN: Bool = false
    ) {
        self.step = step
        self.vin = vin
        self.pairingPIN = pairingPIN
        self.selectedBikeTitle = selectedBikeTitle
            ?? BikeOnboardingL10n.text(.bikeOnboardingBikeFallback)
        self.connectionState = connectionState
        self.discoveredBikes = discoveredBikes
        self.bluetoothState = bluetoothState
        self.discoveryState = discoveryState
        self.isRequestingBluetoothAccess = isRequestingBluetoothAccess
        self.isDiscoveringBikes = isDiscoveringBikes
        self.didCopyPIN = didCopyPIN
    }
}
