import BikeDomain

final class OnboardingPinDeriver: BikePinDeriving, @unchecked Sendable {
    private(set) var receivedVINs: [String] = []
    private let pin: String

    init(pin: String = "654321") {
        self.pin = pin
    }

    func derivePin(vin: String) -> String {
        receivedVINs.append(vin)
        return pin
    }
}
