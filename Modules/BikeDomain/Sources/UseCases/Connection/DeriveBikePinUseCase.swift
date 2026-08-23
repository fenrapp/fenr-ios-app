public struct DeriveBikePinUseCase: Sendable {
    private let pinDeriver: any BikePinDeriving

    public init(pinDeriver: any BikePinDeriving) {
        self.pinDeriver = pinDeriver
    }

    public func execute(vin: String) -> String {
        pinDeriver.derivePin(vin: vin)
    }
}
