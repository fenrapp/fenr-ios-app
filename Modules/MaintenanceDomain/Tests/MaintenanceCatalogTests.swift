import Foundation
import MaintenanceDomain
import Testing

struct MaintenanceCatalogTests {
    @Test("Official recurring schedules preserve calendar and riding-hour intervals")
    func officialRecurringSchedule() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 10)))

        let schedule = try #require(MaintenanceCatalog.suggestedSchedule(
            after: date,
            ridingHours: 20,
            for: .forkOil,
            calendar: calendar
        ))

        #expect(schedule.dueRidingHours == 35)
        #expect(schedule.dueDate == calendar.date(byAdding: .month, value: 12, to: date))
    }

    @Test("Break-in oil is one-time guidance and does not create a recurring schedule")
    func breakInIsNotRecurring() {
        #expect(MaintenanceCatalog.recommendation(for: .breakInGearOil)?.oneTimeRidingHours == 5)
        #expect(MaintenanceCatalog.suggestedSchedule(
            after: Date(),
            ridingHours: 5,
            for: .breakInGearOil
        ) == nil)
    }

    @Test("A schedule becomes due when any configured threshold is reached")
    func dueThresholds() {
        let now = Date(timeIntervalSince1970: 1_000)
        let schedule = MaintenanceSchedule(
            dueDate: now.addingTimeInterval(100),
            dueOdometerKilometers: 500,
            dueRidingHours: 50
        )

        #expect(schedule.status(now: now, odometerKilometers: 500, ridingHours: 10) == .due)
        #expect(schedule.status(now: now, odometerKilometers: 100, ridingHours: 20) == .upcoming)
    }

    @Test("Custom maintenance requires a name")
    func customNameValidation() {
        #expect(!MaintenanceKindSelection(kind: .custom, customName: "  ").isValid)
        #expect(MaintenanceKindSelection(kind: .custom, customName: "Controller check").isValid)
    }

    @Test("Entries reject non-finite measurements and inconsistent cost currencies")
    func entryValidation() {
        let base = MaintenanceEntry(
            vin: "FENRTEST000000001",
            selection: .init(kind: .tires),
            performedAt: Date()
        )
        #expect(base.isValid)
        #expect(!MaintenanceEntry(
            vin: base.vin,
            selection: base.selection,
            performedAt: base.performedAt,
            odometerKilometers: .infinity
        ).isValid)
        #expect(!MaintenanceEntry(
            vin: base.vin,
            selection: base.selection,
            performedAt: base.performedAt,
            costMinorUnits: 1_000
        ).isValid)
    }
}
