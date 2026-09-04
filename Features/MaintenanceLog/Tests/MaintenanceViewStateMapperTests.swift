import Foundation
import MaintenanceDomain
import MaintenanceLog
import MeasurementPresentation
import SettingsDomain
import Testing

struct MaintenanceViewStateMapperTests {
    @Test("Due and upcoming reminders are separated while history remains complete")
    func mapsReminderSections() {
        let now = Date(timeIntervalSince1970: 1_000)
        let mapper = MaintenanceViewStateMapper(
            locale: Locale(identifier: "en_US"),
            now: { now },
            textFormatter: VehicleMeasurementTextFormatter(locale: Locale(identifier: "en_US"))
        )
        let due = MaintenanceEntry(
            vin: Constants.vin,
            selection: .init(kind: .forkOil),
            performedAt: now,
            schedule: .init(dueRidingHours: 15)
        )
        let upcoming = MaintenanceEntry(
            vin: Constants.vin,
            selection: .init(kind: .brakeFluid),
            performedAt: now,
            schedule: .init(dueDate: now.addingTimeInterval(1_000))
        )

        let state = mapper.mapList(
            entries: [due, upcoming],
            measurementSystem: .metric,
            odometerKilometers: nil,
            ridingHours: 15,
            errorMessage: nil
        )

        #expect(state.due.map(\.id) == [due.id])
        #expect(state.upcoming.map(\.id) == [upcoming.id])
        #expect(state.history.count == 2)
    }

    @Test("Imperial presentation converts stored kilometers")
    func convertsOdometer() throws {
        let mapper = MaintenanceViewStateMapper(
            locale: Locale(identifier: "en_US"),
            now: Date.init,
            textFormatter: VehicleMeasurementTextFormatter(locale: Locale(identifier: "en_US"))
        )
        let entry = MaintenanceEntry(
            vin: Constants.vin,
            selection: .init(kind: .tires),
            performedAt: Date(),
            odometerKilometers: 160.9344
        )

        let detail = mapper.mapDetail(entry, measurementSystem: .imperial)
        let odometer = try #require(detail.fields.first { $0.id == "odometer" })
        #expect(odometer.value == "100 mi")
    }

    @Test("Maintenance choices include visual context and selectable currencies")
    func mapsRichFormChoices() {
        let locale = Locale(identifier: "en_GB")
        let mapper = MaintenanceViewStateMapper(
            locale: locale,
            now: Date.init,
            textFormatter: VehicleMeasurementTextFormatter(locale: locale)
        )

        let state = mapper.mapForm(measurementSystem: .metric)

        #expect(state.options.count == MaintenanceKind.allCases.count)
        #expect(state.options.allSatisfy { !$0.detail.isEmpty && !$0.symbolName.isEmpty })
        #expect(state.currencyOptions.first?.id == "GBP")
        #expect(state.currencyOptions.contains { $0.id == "EUR" })
        #expect(Set(state.currencyOptions.map(\.id)).count == state.currencyOptions.count)
    }

    private enum Constants {
        static let vin = "FENRTEST000000001"
    }
}
