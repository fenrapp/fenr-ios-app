import Foundation
import MaintenanceDomain
import MeasurementPresentation
import SettingsDomain

public struct MaintenanceViewStateMapper: Sendable {
    private let locale: Locale
    private let now: @Sendable () -> Date
    private let textFormatter: VehicleMeasurementTextFormatter

    public init(
        locale: Locale,
        now: @escaping @Sendable () -> Date,
        textFormatter: VehicleMeasurementTextFormatter
    ) {
        self.locale = locale
        self.now = now
        self.textFormatter = textFormatter
    }

    public func mapList(
        entries: [MaintenanceEntry],
        measurementSystem: MeasurementSystem,
        odometerKilometers: Double?,
        ridingHours: Double?,
        errorMessage: String?,
        loadErrorMessage: String? = nil
    ) -> MaintenanceLogViewState {
        let rows = entries.map { row($0, measurementSystem: measurementSystem) }
        let active = entries.filter { $0.schedule?.completedAt == nil && $0.schedule?.hasDueValue == true }
        let dueIDs = Set(active.filter {
            $0.schedule?.status(
                now: now(),
                odometerKilometers: odometerKilometers,
                ridingHours: ridingHours
            ) == .due
        }.map(\.id))
        let activeIDs = Set(active.map(\.id))
        return MaintenanceLogViewState(
            status: .loaded,
            due: rows.filter { dueIDs.contains($0.id) },
            upcoming: rows.filter { activeIDs.contains($0.id) && !dueIDs.contains($0.id) },
            history: rows,
            errorMessage: errorMessage,
            loadErrorMessage: loadErrorMessage
        )
    }

    public func mapDetail(
        _ entry: MaintenanceEntry,
        measurementSystem: MeasurementSystem
    ) -> MaintenanceDetailViewState {
        var fields = [MaintenanceDetailViewState.Field(
            id: "date",
            label: String(localized: .maintenanceFieldDate),
            value: dateText(entry.performedAt)
        )]
        if let odometer = entry.odometerKilometers {
            fields.append(.init(
                id: "odometer",
                label: String(localized: .maintenanceFieldOdometer),
                value: distanceText(odometer, measurementSystem: measurementSystem)
            ))
        }
        if let hours = entry.ridingHours {
            fields.append(.init(
                id: "hours",
                label: String(localized: .maintenanceFieldRidingHours),
                value: hoursText(hours)
            ))
        }
        if let workshop = nonempty(entry.workshop) {
            fields.append(.init(id: "workshop", label: String(localized: .maintenanceFieldWorkshop), value: workshop))
        }
        if let cost = costText(entry) {
            fields.append(.init(id: "cost", label: String(localized: .maintenanceFieldCost), value: cost))
        }
        if let notes = nonempty(entry.notes) {
            fields.append(.init(id: "notes", label: String(localized: .maintenanceFieldNotes), value: notes))
        }
        return MaintenanceDetailViewState(
            id: entry.id,
            title: title(for: entry.selection),
            symbolName: symbol(for: entry.selection.kind),
            fields: fields,
            reminderFields: reminderFields(entry.schedule, measurementSystem: measurementSystem),
            officialGuidance: guidance(for: entry.selection.kind)
        )
    }

    public func mapForm(measurementSystem: MeasurementSystem) -> MaintenanceFormViewState {
        let mapper = measurementMapper(for: measurementSystem)
        let currencyCode = locale.currency?.identifier ?? Constants.defaultCurrencyCode
        return MaintenanceFormViewState(
            options: MaintenanceKind.allCases.map {
                .init(
                    id: $0.rawValue,
                    title: title(for: .init(kind: $0)),
                    detail: optionDescription(for: $0),
                    symbolName: symbol(for: $0)
                )
            },
            currencyOptions: currencyOptions(defaultCode: currencyCode),
            distanceUnit: mapper.distance(kilometers: 1).unit
        )
    }

    public func makeDraft(
        entry: MaintenanceEntry?,
        measurementSystem: MeasurementSystem,
        suggestedOdometerKilometers: Double?,
        suggestedRidingHours: Double?
    ) -> MaintenanceFormDraft {
        guard let entry else {
            return MaintenanceFormDraft(
                kindID: MaintenanceKind.generalInspection.rawValue,
                performedAt: now(),
                odometerText: suggestedOdometerKilometers.map {
                    distanceNumber($0, measurementSystem: measurementSystem)
                } ?? "",
                ridingHoursText: suggestedRidingHours.map(hoursNumber) ?? "",
                currencyCode: locale.currency?.identifier ?? Constants.defaultCurrencyCode,
                maximumPerformedAt: now()
            )
        }
        let activeSchedule = entry.schedule?.completedAt == nil ? entry.schedule : nil
        return MaintenanceFormDraft(
            entryID: entry.id,
            kindID: entry.selection.kind.rawValue,
            customName: entry.selection.customName ?? "",
            performedAt: entry.performedAt,
            odometerText: entry.odometerKilometers.map {
                distanceNumber($0, measurementSystem: measurementSystem)
            } ?? "",
            ridingHoursText: entry.ridingHours.map(hoursNumber) ?? "",
            notes: entry.notes ?? "",
            workshop: entry.workshop ?? "",
            costText: entry.costMinorUnits.map { textFormatter.number(Double($0) / 100, fractionDigits: 2) } ?? "",
            currencyCode: entry.currencyCode ?? locale.currency?.identifier ?? Constants.defaultCurrencyCode,
            maximumPerformedAt: now(),
            hasDateReminder: activeSchedule?.dueDate != nil,
            dueDate: activeSchedule?.dueDate ?? entry.performedAt,
            hasOdometerReminder: activeSchedule?.dueOdometerKilometers != nil,
            dueOdometerText: activeSchedule?.dueOdometerKilometers.map {
                distanceNumber($0, measurementSystem: measurementSystem)
            } ?? "",
            hasHoursReminder: activeSchedule?.dueRidingHours != nil,
            dueHoursText: activeSchedule?.dueRidingHours.map(hoursNumber) ?? ""
        )
    }

    public func title(for selection: MaintenanceKindSelection) -> String {
        if selection.kind == .custom { return selection.customName ?? String(localized: .maintenanceKindCustom) }
        return String(localized: localizedTitle(for: selection.kind))
    }

    public func officialGuidance(for kind: MaintenanceKind) -> String? {
        guidance(for: kind)
    }

    public func symbol(for kind: MaintenanceKind) -> String {
        switch kind {
        case .breakInGearOil, .gearOil: "drop.fill"
        case .brakeFluid, .brakePads, .brakeDiscs: "circle.circle"
        case .forkOil, .forkService, .forkBleeding, .shockAndLinkage: "arrow.up.and.down"
        case .motorGearInspection, .chainDrive, .chainLubrication: "gearshape.2.fill"
        case .tires: "circle.dashed"
        case .coolant: "thermometer.medium"
        case .bearings: "circle.hexagongrid.fill"
        case .electrical: "bolt.fill"
        case .generalInspection: "checkmark.seal.fill"
        case .custom: "wrench.and.screwdriver.fill"
        }
    }
}

private extension MaintenanceViewStateMapper {
    func row(_ entry: MaintenanceEntry, measurementSystem: MeasurementSystem) -> MaintenanceLogViewState.Row {
        let details = [
            entry.odometerKilometers.map { distanceText($0, measurementSystem: measurementSystem) },
            entry.ridingHours.map(hoursText)
        ].compactMap { $0 }
        return .init(
            id: entry.id,
            symbolName: symbol(for: entry.selection.kind),
            title: title(for: entry.selection),
            dateText: dateText(entry.performedAt),
            detailText: details.isEmpty ? nil : details.joined(separator: " · "),
            reminderText: reminderFields(entry.schedule, measurementSystem: measurementSystem)
                .map { "\($0.label): \($0.value)" }
                .joined(separator: " · ")
                .nilIfEmpty
        )
    }

    func reminderFields(
        _ schedule: MaintenanceSchedule?,
        measurementSystem: MeasurementSystem
    ) -> [MaintenanceDetailViewState.Field] {
        guard let schedule, schedule.completedAt == nil else { return [] }
        var fields: [MaintenanceDetailViewState.Field] = []
        if let date = schedule.dueDate {
            fields.append(.init(id: "dueDate", label: String(localized: .maintenanceDueDate), value: dateText(date)))
        }
        if let odometer = schedule.dueOdometerKilometers {
            fields.append(.init(
                id: "dueOdometer",
                label: String(localized: .maintenanceDueOdometer),
                value: distanceText(odometer, measurementSystem: measurementSystem)
            ))
        }
        if let hours = schedule.dueRidingHours {
            fields.append(.init(
                id: "dueHours",
                label: String(localized: .maintenanceDueHours),
                value: hoursText(hours)
            ))
        }
        return fields
    }

    func distanceText(_ kilometers: Double, measurementSystem: MeasurementSystem) -> String {
        let measurement = measurementMapper(for: measurementSystem).distance(kilometers: kilometers)
        return textFormatter.string(from: measurement, fractionDigits: 1)
    }

    func distanceNumber(_ kilometers: Double, measurementSystem: MeasurementSystem) -> String {
        let measurement = measurementMapper(for: measurementSystem).distance(kilometers: kilometers)
        return textFormatter.number(measurement.value, fractionDigits: 1)
    }

    func measurementMapper(for system: MeasurementSystem) -> VehicleMeasurementMapper {
        VehicleMeasurementMapper(measurementSystem: system.resolved(for: locale))
    }

    func hoursText(_ hours: Double) -> String {
        hoursNumber(hours) + " " + String(localized: .maintenanceHoursUnit)
    }

    func hoursNumber(_ hours: Double) -> String {
        textFormatter.number(hours, fractionDigits: 1)
    }

    func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).day().month(.abbreviated).year())
    }

    func costText(_ entry: MaintenanceEntry) -> String? {
        guard let minor = entry.costMinorUnits, let code = entry.currencyCode else { return nil }
        return (Double(minor) / 100).formatted(.currency(code: code).locale(locale))
    }

    func nonempty(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func guidance(for kind: MaintenanceKind) -> String? {
        switch kind {
        case .breakInGearOil: String(localized: .maintenanceGuidanceBreakIn)
        case .brakeFluid: String(localized: .maintenanceGuidanceBrakeFluid)
        case .forkOil: String(localized: .maintenanceGuidanceForkOil)
        case .forkService: String(localized: .maintenanceGuidanceForkService)
        case .motorGearInspection: String(localized: .maintenanceGuidanceMotorInspection)
        case .chainLubrication: String(localized: .maintenanceGuidanceChain)
        case .forkBleeding: String(localized: .maintenanceGuidanceForkBleeding)
        default: nil
        }
    }

    func optionDescription(for kind: MaintenanceKind) -> String {
        if let guidance = guidance(for: kind) { return guidance }
        return String(localized: optionDescriptionResource(for: kind))
    }

    func optionDescriptionResource(for kind: MaintenanceKind) -> LocalizedStringResource {
        switch kind {
        case .tires: .maintenanceDescriptionTires
        case .brakePads: .maintenanceDescriptionBrakePads
        case .brakeDiscs: .maintenanceDescriptionBrakeDiscs
        case .chainDrive: .maintenanceDescriptionChainDrive
        case .coolant: .maintenanceDescriptionCoolant
        case .shockAndLinkage: .maintenanceDescriptionShockAndLinkage
        case .gearOil: .maintenanceDescriptionGearOil
        case .bearings: .maintenanceDescriptionBearings
        case .electrical: .maintenanceDescriptionElectrical
        case .generalInspection: .maintenanceDescriptionGeneralInspection
        case .custom: .maintenanceDescriptionCustom
        default: .maintenanceDescriptionGeneralInspection
        }
    }

    func currencyOptions(defaultCode: String) -> [MaintenanceFormViewState.CurrencyOption] {
        var seen = Set<String>()
        return ([defaultCode] + Constants.currencyCodes).compactMap { code in
            guard seen.insert(code).inserted else { return nil }
            let name = locale.localizedString(forCurrencyCode: code) ?? code
            return .init(id: code, title: "\(code) · \(name)")
        }
    }

    func localizedTitle(for kind: MaintenanceKind) -> LocalizedStringResource {
        switch kind {
        case .breakInGearOil: .maintenanceKindBreakInGearOil
        case .brakeFluid: .maintenanceKindBrakeFluid
        case .forkOil: .maintenanceKindForkOil
        case .forkService: .maintenanceKindForkService
        case .motorGearInspection: .maintenanceKindMotorGearInspection
        case .chainLubrication: .maintenanceKindChainLubrication
        case .forkBleeding: .maintenanceKindForkBleeding
        default: generalLocalizedTitle(for: kind)
        }
    }

    func generalLocalizedTitle(for kind: MaintenanceKind) -> LocalizedStringResource {
        switch kind {
        case .tires: .maintenanceKindTires
        case .brakePads: .maintenanceKindBrakePads
        case .brakeDiscs: .maintenanceKindBrakeDiscs
        case .chainDrive: .maintenanceKindChainDrive
        case .coolant: .maintenanceKindCoolant
        case .shockAndLinkage: .maintenanceKindShockAndLinkage
        case .gearOil: .maintenanceKindGearOil
        case .bearings: .maintenanceKindBearings
        case .electrical: .maintenanceKindElectrical
        case .generalInspection: .maintenanceKindGeneralInspection
        case .custom: .maintenanceKindCustom
        default: .maintenanceKindCustom
        }
    }
}

private extension MaintenanceViewStateMapper {
    enum Constants {
        static let defaultCurrencyCode = "EUR"
        static let currencyCodes = ["EUR", "USD", "GBP", "CHF", "CAD", "AUD", "JPY", "SEK", "NOK", "DKK", "PLN"]
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
