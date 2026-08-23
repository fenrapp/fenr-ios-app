import BikeDomain

struct FakeBikePinDeriver: BikePinDeriving {
    func derivePin(vin: String) -> String { "999999" }
}
