import Foundation

enum BatteryHealthText {
    static let placeholder = String(localized: .batteryHealthPlaceholder)
    static let awaitingSample = String(localized: .batteryHealthDatasetAwaitingSample)
    static let validated = String(localized: .batteryHealthDatasetValidated)
    static let summary = String(localized: .batteryHealthSectionSummary)
    static let pack = String(localized: .batteryHealthSectionPack)
    static let charging = String(localized: .batteryHealthSectionCharging)
    static let cells = String(localized: .batteryHealthSectionCells)
    static let temperatures = String(localized: .batteryHealthSectionTemperatures)
    static let dataSources = String(localized: .batteryHealthSectionDataSources)
    static let chargePowerControl = String(localized: .batteryHealthSectionChargePower)
    static let noValidatedCells = String(localized: .batteryHealthCellsEmpty)
    static let noValidatedTemperatures = String(localized: .batteryHealthTemperaturesEmpty)
    static let copyLog = String(localized: .batteryHealthCopyLogButton)
}
