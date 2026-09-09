import Foundation

public enum PowerModeAdvancedIntent {
    case selectMap(Int)
    case selectCurve(PowerModeCurveKind)
    case setPoint(index: Int, value: Double)
    case setTraction(id: PowerModeAdjustmentID, value: Double)
    case apply
    case discard
    case refresh
    case savePreset(String)
    case renamePreset(id: UUID, name: String)
    case duplicatePreset(UUID)
    case deletePreset(UUID)
    case loadPreset(UUID)
}
