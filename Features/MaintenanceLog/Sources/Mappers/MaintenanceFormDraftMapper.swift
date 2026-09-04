import Foundation
import MaintenanceDomain
import SettingsDomain

public struct MaintenanceFormDraftMapper: Sendable {
    private let numberParser: MaintenanceNumberParser
    private let locale: Locale
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        numberParser: MaintenanceNumberParser,
        locale: Locale,
        calendar: Calendar,
        now: @escaping @Sendable () -> Date
    ) {
        self.numberParser = numberParser
        self.locale = locale
        self.calendar = calendar
        self.now = now
    }

    public func map(
        _ draft: MaintenanceFormDraft,
        vin: String,
        existing: MaintenanceEntry?,
        measurementSystem: MeasurementSystem
    ) -> MaintenanceEntry? {
        guard draft.performedAt <= now(),
              let kind = MaintenanceKind(rawValue: draft.kindID) else { return nil }
        let selection = MaintenanceKindSelection(kind: kind, customName: draft.customName)
        guard selection.isValid else { return nil }
        let odometer = distanceInKilometers(draft.odometerText, measurementSystem: measurementSystem)
        let ridingHours = number(draft.ridingHoursText)
        let dueOdometer = draft.hasOdometerReminder
            ? distanceInKilometers(draft.dueOdometerText, measurementSystem: measurementSystem)
            : nil
        let dueHours = draft.hasHoursReminder ? number(draft.dueHoursText) : nil
        guard draft.odometerText.isEmpty || odometer != nil,
              draft.ridingHoursText.isEmpty || ridingHours != nil,
              !draft.hasOdometerReminder || dueOdometer != nil,
              !draft.hasHoursReminder || dueHours != nil,
              !draft.hasDateReminder || draft.dueDate >= draft.performedAt else { return nil }
        guard case .value(let costMinorUnits) = parsedCost(draft.costText) else { return nil }
        let proposedSchedule = MaintenanceSchedule(
            dueDate: draft.hasDateReminder ? draft.dueDate : nil,
            dueOdometerKilometers: dueOdometer,
            dueRidingHours: dueHours
        )
        let schedule: MaintenanceSchedule? = if proposedSchedule.hasDueValue {
            proposedSchedule
        } else if existing?.schedule?.completedAt != nil {
            existing?.schedule
        } else {
            nil
        }
        return MaintenanceEntry(
            id: existing?.id ?? UUID(),
            vin: vin,
            selection: selection,
            performedAt: draft.performedAt,
            odometerKilometers: odometer,
            ridingHours: ridingHours,
            notes: normalized(draft.notes),
            workshop: normalized(draft.workshop),
            costMinorUnits: costMinorUnits,
            currencyCode: costMinorUnits == nil ? nil : draft.currencyCode,
            schedule: schedule,
            createdAt: existing?.createdAt ?? now(),
            updatedAt: now()
        )
    }

    public func number(_ text: String) -> Double? {
        guard let value = numberParser.parse(text), value >= 0 else { return nil }
        return value
    }

    public func suggestedSchedule(
        after date: Date,
        ridingHoursText: String,
        for kind: MaintenanceKind
    ) -> MaintenanceSchedule? {
        MaintenanceCatalog.suggestedSchedule(
            after: date,
            ridingHours: number(ridingHoursText),
            for: kind,
            calendar: calendar
        )
    }
}

private extension MaintenanceFormDraftMapper {
    func distanceInKilometers(_ text: String, measurementSystem: MeasurementSystem) -> Double? {
        guard let value = number(text) else { return nil }
        return measurementSystem.resolved(for: locale) == .us
            ? Measurement(value: value, unit: UnitLength.miles).converted(to: .kilometers).value
            : value
    }

    func parsedCost(_ text: String) -> ParsedCost {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .value(nil) }
        guard let cost = number(text) else { return .invalid }
        let roundedMinorUnits = (cost * 100).rounded()
        guard roundedMinorUnits.isFinite,
              roundedMinorUnits < Double(Int64.max) else { return .invalid }
        return .value(Int64(roundedMinorUnits))
    }

    func normalized(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    enum ParsedCost {
        case invalid
        case value(Int64?)
    }
}
