import BikeDomain

struct BikeEmulatorPowerCurveStore: Sendable {
    private let calibration: BikePowerCurveCalibration
    private var configurations: [Int: BikeAdvancedPowerModeConfiguration] = [:]
    private var confirmations: [Int: BikePowerModeCurveConfirmation] = [:]

    init(calibration: BikePowerCurveCalibration) {
        self.calibration = calibration
    }

    mutating func reset() {
        configurations.removeAll()
        confirmations.removeAll()
    }

    mutating func read(_ basic: BikePowerModeConfiguration, maximum: Int) throws -> BikeAdvancedPowerModeConfiguration {
        if let current = configurations[basic.mapIndex] { return current }
        guard let horsepower = basic.horsepower, let regeneration = basic.regenerativeBrakingPercent,
              regeneration.isFinite, 0 ... 100 ~= regeneration else {
            throw BikeEmulatorPowerModeError.readFailure
        }
        let value = BikeAdvancedPowerModeConfiguration(
            mapIndex: basic.mapIndex, firmware: "1.10.1", torqueRaw: Int((Double(horsepower) * 1.25).rounded()),
            regenerationRaw: Int(regeneration), curve: basic.mapIndex + 1,
            power: powerSamples(horsepower: horsepower, maximum: maximum),
            regeneration: Array(
                repeating: Int((regeneration * 10).rounded()), count: BikePowerCurveCalibration.sampleCount
            ),
            powerTractionRaw: basic.powerTractionPercent.map { Int(($0 * 10).rounded()) },
            brakingTractionRaw: basic.brakingTractionPercent.map { Int(($0 * 10).rounded()) }
        )
        configurations[basic.mapIndex] = value
        return value
    }

    func changingBasic(
        _ current: BikeAdvancedPowerModeConfiguration, horsepower: Int?, regeneration: Int?, maximum: Int
    ) throws -> BikeAdvancedPowerModeConfiguration {
        var desired = current
        if let horsepower {
            guard 10 ... maximum ~= horsepower else { throw BikeEmulatorPowerModeError.invalidConfiguration }
            let torque = Int((Double(horsepower) * 1.25).rounded())
            if torque != current.torqueRaw {
                desired.torqueRaw = torque
                desired.power = powerSamples(horsepower: horsepower, maximum: maximum)
            }
        }
        if let regeneration {
            guard 0 ... 100 ~= regeneration else { throw BikeEmulatorPowerModeError.invalidConfiguration }
            if regeneration != current.regenerationRaw {
                desired.regenerationRaw = regeneration
                desired.regeneration = Array(repeating: regeneration * 10, count: BikePowerCurveCalibration.sampleCount)
            }
        }
        return desired
    }

    mutating func apply(
        expected: BikeAdvancedPowerModeConfiguration,
        desired: BikeAdvancedPowerModeConfiguration, maximum: Int, isAdvancedEdit: Bool = true
    ) throws -> BikePowerModeConfiguration {
        guard configurations[expected.mapIndex] == expected,
              desired.mapIndex == expected.mapIndex, desired.firmware == expected.firmware,
              desired.curve == expected.curve, desired.curve == desired.mapIndex + 1,
              13 ... 100 ~= desired.torqueRaw, 0 ... 100 ~= desired.regenerationRaw,
              desired.power.count == BikePowerCurveCalibration.sampleCount,
              desired.regeneration.count == BikePowerCurveCalibration.sampleCount,
              desired.power.allSatisfy({ 0 ... 1_000 ~= $0 }),
              desired.regeneration.allSatisfy({ 0 ... 1_000 ~= $0 }),
              validTraction(desired.powerTractionRaw, previous: expected.powerTractionRaw),
              validTraction(desired.brakingTractionRaw, previous: expected.brakingTractionRaw),
              desired.power == expected.power
                || calibration.isRideable(desired.power, maximumHorsepower: maximum) else {
            throw BikeEmulatorPowerModeError.invalidConfiguration
        }
        configurations[desired.mapIndex] = desired
        let confirmation = (confirmations[desired.mapIndex] ?? .init()).confirming(
            desired, advancedEditBaseline: isAdvancedEdit ? expected : nil
        )
        confirmations[desired.mapIndex] = confirmation
        return .init(
            mapIndex: desired.mapIndex, horsepower: Int((Double(desired.torqueRaw) / 1.25).rounded()),
            regenerativeBrakingPercent: Double(desired.regenerationRaw),
            powerTractionPercent: desired.powerTractionRaw.map { Double($0) / 10 },
            brakingTractionPercent: desired.brakingTractionRaw.map { Double($0) / 10 },
            curveConfirmation: confirmation
        )
    }

    private func powerSamples(horsepower: Int, maximum: Int) -> [Int] {
        (0 ..< BikePowerCurveCalibration.sampleCount).map { index in
            calibration.torque(
                horsepower: min(Double(horsepower), calibration.maximum(at: index, maximumHorsepower: maximum)),
                index: index
            )
        }
    }

    private func validTraction(_ value: Int?, previous: Int?) -> Bool {
        guard let previous else { return value == nil }
        return value.map { $0 == previous || 0 ... 1_000 ~= $0 } ?? false
    }
}
