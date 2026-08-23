import BikeDomain
import StarkProtocol

public struct StarkBikePinDeriver: BikePinDeriving {
    public init() {}

    public func derivePin(vin: String) -> String {
        StarkPin.derive(vin: vin)
    }
}
