import Foundation

public struct MaintenanceEntry: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let vin: String
    public var selection: MaintenanceKindSelection
    public var performedAt: Date
    public var odometerKilometers: Double?
    public var ridingHours: Double?
    public var notes: String?
    public var workshop: String?
    public var costMinorUnits: Int64?
    public var currencyCode: String?
    public var schedule: MaintenanceSchedule?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        vin: String,
        selection: MaintenanceKindSelection,
        performedAt: Date,
        odometerKilometers: Double? = nil,
        ridingHours: Double? = nil,
        notes: String? = nil,
        workshop: String? = nil,
        costMinorUnits: Int64? = nil,
        currencyCode: String? = nil,
        schedule: MaintenanceSchedule? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.vin = vin
        self.selection = selection
        self.performedAt = performedAt
        self.odometerKilometers = odometerKilometers
        self.ridingHours = ridingHours
        self.notes = notes
        self.workshop = workshop
        self.costMinorUnits = costMinorUnits
        self.currencyCode = currencyCode
        self.schedule = schedule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isValid: Bool {
        !vin.isEmpty
            && selection.isValid
            && performedAt.timeIntervalSinceReferenceDate.isFinite
            && createdAt.timeIntervalSinceReferenceDate.isFinite
            && updatedAt.timeIntervalSinceReferenceDate.isFinite
            && isNonnegativeFinite(odometerKilometers)
            && isNonnegativeFinite(ridingHours)
            && costMinorUnits.map { $0 >= 0 } != false
            && hasConsistentCurrency
            && isNonnegativeFinite(schedule?.dueOdometerKilometers)
            && isNonnegativeFinite(schedule?.dueRidingHours)
            && schedule?.dueDate?.timeIntervalSinceReferenceDate.isFinite != false
    }

    private var hasConsistentCurrency: Bool {
        if costMinorUnits == nil { return currencyCode == nil }
        return currencyCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func isNonnegativeFinite(_ value: Double?) -> Bool {
        value.map { $0.isFinite && $0 >= 0 } != false
    }
}
