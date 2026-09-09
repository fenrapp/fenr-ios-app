import BikeDomain

struct PowerModeCurveReadContext: Sendable {
    let generation: UInt64
    let revision: UInt64
    let mapIndex: Int
    let confirmation: BikePowerModeCurveConfirmation
}
