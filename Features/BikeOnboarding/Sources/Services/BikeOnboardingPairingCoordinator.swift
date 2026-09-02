import BikeDomain
import StarkProtocol

struct BikeOnboardingPairingSelection: Sendable {
    let vin: String
    let title: String
    let pin: String
}

@MainActor
public struct BikeOnboardingPairingCoordinator {
    private let derivePin: DeriveBikePinUseCase
    private let clipboard: any BikeOnboardingClipboardWriting

    public init(
        derivePin: DeriveBikePinUseCase,
        clipboard: any BikeOnboardingClipboardWriting
    ) {
        self.derivePin = derivePin
        self.clipboard = clipboard
    }

    func selection(vin: String, title: String) -> BikeOnboardingPairingSelection? {
        let normalizedVIN = StarkPairingIdentity.normalizedVIN(vin)
        guard StarkPairingIdentity.isValidVIN(normalizedVIN) else { return nil }
        return BikeOnboardingPairingSelection(
            vin: normalizedVIN,
            title: title,
            pin: derivePin.execute(vin: normalizedVIN)
        )
    }

    func normalizedVIN(_ vin: String?) -> String {
        vin.map(StarkPairingIdentity.normalizedVIN) ?? ""
    }

    func copy(pin: String) -> Bool {
        guard !pin.isEmpty else { return false }
        clipboard.copy(pin)
        return true
    }

    func canConnect(vin: String) -> Bool {
        StarkPairingIdentity.isValidVIN(vin)
    }

    func matches(peripheralName: String?, targetVIN: String) -> Bool {
        guard let peripheralName else { return true }
        return StarkPairingIdentity.matches(peripheralName, targetVIN: targetVIN)
    }
}
