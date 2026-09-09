import BikeDomain

public struct PowerModeAdvancedUseCases: Sendable {
    let editing: BikePowerModeEditingUseCases?
    let calibration: BikePowerCurveCalibration

    public init(editing: BikePowerModeEditingUseCases?, calibration: BikePowerCurveCalibration) {
        self.editing = editing
        self.calibration = calibration
    }
}
