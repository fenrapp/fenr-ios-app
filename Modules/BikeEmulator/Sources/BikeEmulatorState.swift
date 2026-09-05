import BikeDomain
import Foundation

public struct BikeEmulatorState: Codable, Equatable, Sendable {
    public var version = 1
    public var scenario: BikeEmulatorScenario
    public var powerModePreset: BikeEmulatorPowerModePreset
    public var activeMap: Int
    public var chargePowerWatts = 1_000
    public var chargeTargetPercent = 100
    public var isBikeLocked = false
    public var distanceKilometers = 0.0
    public var maps: [Map] = []

    public init(
        scenario: BikeEmulatorScenario = .parked,
        powerModePreset: BikeEmulatorPowerModePreset = .alpha,
        activeMap: Int = 4
    ) {
        self.scenario = scenario
        self.powerModePreset = powerModePreset
        self.activeMap = activeMap
    }

    public var isValid: Bool {
        version == 1 && (1 ... 5).contains(activeMap)
            && (300 ... 3_300).contains(chargePowerWatts)
            && (1 ... 100).contains(chargeTargetPercent)
            && distanceKilometers.isFinite && distanceKilometers >= 0
            && maps.allSatisfy(\.isValid)
            && Set(maps.map(\.index)).count == maps.count
    }

    public struct Map: Codable, Equatable, Sendable {
        public let index: Int
        public let horsepower: Int?
        public let regeneration: Double?
        public let powerTraction: Double?
        public let brakingTraction: Double?

        init(_ configuration: BikePowerModeConfiguration) {
            index = configuration.mapIndex
            horsepower = configuration.horsepower
            regeneration = configuration.regenerativeBrakingPercent
            powerTraction = configuration.powerTractionPercent
            brakingTraction = configuration.brakingTractionPercent
        }

        var configuration: BikePowerModeConfiguration {
            .init(
                mapIndex: index, horsepower: horsepower, regenerativeBrakingPercent: regeneration,
                powerTractionPercent: powerTraction, brakingTractionPercent: brakingTraction
            )
        }

        var isValid: Bool {
            (0 ... 4).contains(index)
                && horsepower.map { (10 ... 80).contains($0) } != false
                && [regeneration, powerTraction, brakingTraction].allSatisfy {
                    $0.map { $0.isFinite && (-100 ... 100).contains($0) } != false
                }
        }
    }
}
