import BikeDomain
import Foundation

struct PowerModeBasicWriter: Sendable {
    let useCases: PowerModeSettingsUseCases
    let advanced: PowerModeAdvancedUseCases

    func execute(
        map: Int, id: PowerModeAdjustmentID, value: Double, maximum: Int,
        configuration: BikePowerModeConfiguration?
    ) async throws -> PowerModeBasicWriteResult {
        if let editing = advanced.editing {
            return try await writeEditing(editing, map: map, id: id, value: value, maximum: maximum)
        }
        guard let configuration else { throw BikePowerCurveError.invalidValues }
        return try await writeLegacy(configuration, map: map, id: id, value: value)
    }

    private func writeEditing(
        _ editing: BikePowerModeEditingUseCases, map: Int, id: PowerModeAdjustmentID, value: Double, maximum: Int
    ) async throws -> PowerModeBasicWriteResult {
        do {
            let confirmed: BikeAdvancedPowerModeConfiguration
            switch id {
            case .power, .regeneration:
                confirmed = try await editing.applyBasic(
                    mapIndex: map, horsepower: id == .power ? Int(value) : nil,
                    regeneration: id == .regeneration ? Int(value) : nil
                )
            case .powerTraction, .brakingTraction:
                let current = try await editing.read(mapIndex: map)
                try Task.checkCancellation()
                var desired = current
                if id == .powerTraction {
                    desired.powerTractionRaw = Int(value * 10)
                } else { desired.brakingTractionRaw = Int(value * 10) }
                confirmed = try await editing.apply(expected: current, desired: desired, maximumHorsepower: maximum)
            }
            return .init(advanced: confirmed, values: nil, error: nil)
        } catch {
            try Task.checkCancellation()
            let actual = try? await editing.read(mapIndex: map)
            try Task.checkCancellation()
            return .init(advanced: actual, values: nil, error: String(localized: .powerCurveApplyError))
        }
    }

    private func writeLegacy(
        _ configuration: BikePowerModeConfiguration, map: Int, id: PowerModeAdjustmentID, value: Double
    ) async throws -> PowerModeBasicWriteResult {
        let values: PowerModeBasicWriteResult.Values
        switch id {
        case .power, .regeneration:
            guard let horsepower = configuration.horsepower,
                  let regeneration = configuration.regenerativeBrakingPercent else {
                throw BikePowerCurveError.invalidValues
            }
            values = .base(
                horsepower: id == .power ? Int(value.rounded()) : horsepower,
                regeneration: id == .regeneration ? Int(value.rounded()) : Int(regeneration.rounded())
            )
        case .powerTraction, .brakingTraction:
            guard let power = configuration.powerTractionPercent, let braking = configuration.brakingTractionPercent,
                  [power, braking].allSatisfy({ $0.isFinite && 0 ... 100 ~= $0 && $0.rounded() == $0 }) else {
                throw BikePowerCurveError.invalidValues
            }
            values = .traction(
                power: id == .powerTraction ? value : power, braking: id == .brakingTraction ? value : braking
            )
        }
        do {
            switch values {
            case .base(let horsepower, let regeneration):
                try await useCases.setPowerModeConfiguration.execute(
                    mapIndex: map, horsepower: horsepower, regenerativeBrakingPercent: regeneration
                )
            case .traction(let power, let braking):
                try await useCases.setTractionControlConfiguration.execute(
                    mapIndex: map, powerTractionPercent: power, brakingTractionPercent: braking
                )
            }
            return .init(advanced: nil, values: values, error: nil)
        } catch {
            try Task.checkCancellation()
            return .init(advanced: nil, values: nil, error: String(localized:
                id == .power || id == .regeneration
                    ? .powerModeSettingsApplyMapError : .powerModeSettingsApplyTractionError
            ))
        }
    }
}
