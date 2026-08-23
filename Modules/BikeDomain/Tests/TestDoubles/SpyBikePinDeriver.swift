import BikeDomain

struct SpyBikePinDeriver: BikePinDeriving {
    func derivePin(vin: String) -> String { "123456" }
}
