import BikeDomain

struct PowerModeBasicWriteResult: Sendable {
    enum Values: Sendable {
        case base(horsepower: Int, regeneration: Int)
    }
    let advanced: BikeAdvancedPowerModeConfiguration?
    let values: Values?
    let error: String?
}
