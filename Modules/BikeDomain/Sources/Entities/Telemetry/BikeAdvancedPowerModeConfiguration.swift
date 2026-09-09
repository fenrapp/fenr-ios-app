import Foundation

public struct BikeAdvancedPowerModeConfiguration: Codable, Equatable, Sendable {
    public let mapIndex: Int
    public let firmware: String
    public var torqueRaw: Int
    public var regenerationRaw: Int
    public let curve: Int
    public var power: [Int]
    public var regeneration: [Int]
    public var powerTractionRaw: Int?
    public var brakingTractionRaw: Int?

    public init(
        mapIndex: Int, firmware: String, torqueRaw: Int, regenerationRaw: Int, curve: Int,
        power: [Int], regeneration: [Int], powerTractionRaw: Int?, brakingTractionRaw: Int?
    ) {
        self.mapIndex = mapIndex
        self.firmware = firmware
        self.torqueRaw = torqueRaw
        self.regenerationRaw = regenerationRaw
        self.curve = curve
        self.power = power
        self.regeneration = regeneration
        self.powerTractionRaw = powerTractionRaw
        self.brakingTractionRaw = brakingTractionRaw
    }
}
