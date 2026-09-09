import Foundation

public struct BikePowerCurveCalibration: Sendable {
    public static let profileID = "power-curve-calibration-v1"
    public static let editorRPM = [1_000, 2_000, 3_000, 4_000, 5_000, 6_000, 8_000, 10_000, 12_000, 14_000]
    public static let editorSampleIndexes = [0, 1, 2, 3, 4, 5, 7, 9, 11, 13]
    public static let sampleCount = 15
    private let table: [[Int]]
    private let horsepowerRows: [Int]
    private let limits: [Int]
    private let standardRatios: [Float]

    public init(table: [[Int]], horsepowerRows: [Int], limits: [Int], standardRatios: [Float]) {
        self.table = table
        self.horsepowerRows = horsepowerRows
        self.limits = limits
        self.standardRatios = standardRatios
    }

    public func maximum(at index: Int, maximumHorsepower: Int) -> Double {
        let ratio: Float = maximumHorsepower > 60 ? 1 : standardRatios[index]
        return Double(ratio * Float(min(limits[index], maximumHorsepower)))
    }

    public func horsepower(raw: Int, index: Int, maximumHorsepower: Int) -> Double {
        let ceiling = maximum(at: index, maximumHorsepower: maximumHorsepower)
        let upperRaw = torque(horsepower: ceiling, index: index)
        if raw >= upperRaw { return ceiling }
        for row in 1 ..< horsepowerRows.count where raw <= table[row][index] {
            let lower = table[row - 1][index]
            let upper = table[row][index]
            guard upper > lower else { continue }
            let lowHP = Float(horsepowerRows[row - 1])
            let highHP = Float(min(horsepowerRows[row], limits[index]))
            let fraction = Float(raw - lower) / Float(upper - lower)
            return max(0, min(ceiling, Double(lowHP + fraction * (highHP - lowHP))))
        }
        return ceiling
    }

    public func torque(horsepower: Double, index: Int) -> Int {
        let value = Float(horsepower)
        for row in 1 ..< horsepowerRows.count where value <= Float(horsepowerRows[row]) {
            let lowerHP = Float(horsepowerRows[row - 1])
            let upperHP = Float(min(horsepowerRows[row], limits[index]))
            let lowerRaw = table[row - 1][index]
            let upperRaw = table[row][index]
            guard upperHP > lowerHP else { return upperRaw }
            let fraction = (value - lowerHP) / (upperHP - lowerHP)
            return min(1_000, max(0, lowerRaw + Int(floor(Float(upperRaw - lowerRaw) * fraction + 0.5))))
        }
        return 1_000
    }

    public func isRideable(_ values: [Int], maximumHorsepower: Int) -> Bool {
        guard values.count == Self.sampleCount else { return false }
        return (12 ..< Self.sampleCount).allSatisfy {
            horsepower(raw: values[$0], index: $0, maximumHorsepower: maximumHorsepower).rounded() >= 10
        }
    }

    public func summaryHorsepower(_ values: [Int], maximumHorsepower: Int) -> Int {
        guard values.count == Self.sampleCount else { return 0 }
        return values.enumerated().map {
            Int(floor(horsepower(raw: $0.element, index: $0.offset, maximumHorsepower: maximumHorsepower) + 0.5))
        }.max() ?? 0
    }

    public func editorPower(_ values: [Int], maximumHorsepower: Int) -> [Double] {
        guard values.count == Self.sampleCount else { return [] }
        return Self.editorSampleIndexes.map {
            horsepower(raw: values[$0], index: $0, maximumHorsepower: maximumHorsepower)
        }
    }

    public func powerSamples(points: [Double], maximumHorsepower: Int) throws -> [Int] {
        guard points.count == Self.editorRPM.count else { throw BikePowerCurveError.invalidValues }
        let scale = try zip(Self.editorSampleIndexes, points).map { index, value in
            let limit = maximum(at: index, maximumHorsepower: maximumHorsepower)
            guard value.isFinite, value >= 0, value <= limit else { throw BikePowerCurveError.invalidValues }
            return Int(floor(Float(value) * 1_000 / Float(limit) + 0.5))
        }
        return expand(scale).enumerated().map { index, value in
            let horsepower = Float(value) / 1_000 * Float(maximum(at: index, maximumHorsepower: maximumHorsepower))
            return torque(horsepower: Double(horsepower), index: index)
        }
    }

    public func updatingPower(
        _ configuration: BikeAdvancedPowerModeConfiguration, points: [Double], maximumHorsepower: Int
    ) throws -> BikeAdvancedPowerModeConfiguration {
        var result = configuration
        result.power = try powerSamples(points: points, maximumHorsepower: maximumHorsepower)
        let horsepower = summaryHorsepower(result.power, maximumHorsepower: maximumHorsepower)
        result.torqueRaw = Int(floor(Double(horsepower) * 1.25 + 0.5))
        return result
    }

    public func updatingRegeneration(
        _ configuration: BikeAdvancedPowerModeConfiguration, points: [Double]
    ) throws -> BikeAdvancedPowerModeConfiguration {
        var result = configuration
        result.regeneration = try regenerationSamples(points: points)
        result.regenerationRaw = (result.regeneration.max() ?? 0) / 10
        return result
    }

    public func regenerationSamples(points: [Double]) throws -> [Int] {
        guard points.count == Self.editorRPM.count else { throw BikePowerCurveError.invalidValues }
        return try expand(points.map {
            guard $0.isFinite, 0 ... 100 ~= $0 else { throw BikePowerCurveError.invalidValues }
            return Int(floor($0 * 10 + 0.5))
        })
    }

    private func expand(_ points: [Int]) -> [Int] {
        var result: [Int] = []
        for (index, point) in points.enumerated() {
            if index > 0, Self.editorRPM[index] - Self.editorRPM[index - 1] > 1_000 {
                result.append((points[index - 1] + point) / 2)
            }
            result.append(point)
        }
        result.append(points[points.count - 1])
        return result
    }
}
