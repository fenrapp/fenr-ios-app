import BikeDomain
import Foundation
import MaintenanceDomain
@testable import MaintenanceLog
import MeasurementPresentation
import SettingsDomain
import TestSupport
import VehicleSession

@MainActor
enum MaintenanceTestFactory {
    nonisolated static let now = Date(timeIntervalSince1970: 10_000)

    static func make(
        entries: [MaintenanceEntry] = [],
        vin: String = Constants.firstVIN,
        locale: Locale = Locale(identifier: "en_US")
    ) -> Fixture {
        let operation = ControllableMaintenanceOperation()
        let repository = MaintenanceTestRepository(entries: entries, operation: operation)
        let session = MaintenanceTestVehicleSession(snapshot: snapshot(vin: vin))
        let reminders = MaintenanceReminderRecorder(schedulingGate: TestEventHub(bufferingPolicy: .unbounded))
        let clock: @Sendable () -> Date = { now }
        let viewModel = MaintenanceViewModel(
            useCases: .init(
                loadEntries: .init(repository: repository),
                saveEntry: .init(repository: repository),
                deleteEntry: .init(repository: repository)
            ),
            vehicleSession: session,
            mapper: .init(
                locale: locale,
                now: clock,
                textFormatter: VehicleMeasurementTextFormatter(locale: locale)
            ),
            draftMapper: .init(
                numberParser: .init(locale: locale),
                locale: locale,
                calendar: Calendar(identifier: .gregorian),
                now: clock
            ),
            reminderScheduler: reminders,
            now: clock
        )
        return .init(
            viewModel: viewModel,
            repository: repository,
            session: session,
            reminders: reminders,
            operation: operation
        )
    }

    static func snapshot(vin: String, measurementSystem: MeasurementSystem = .metric) -> VehicleSessionSnapshot {
        .init(
            settings: .init(measurementSystem: measurementSystem),
            profile: .init(vin: vin),
            hasReceivedSettings: true,
            hasReceivedProfile: true,
            isCanonicalTelemetryAvailable: false
        )
    }

    struct Fixture {
        let viewModel: MaintenanceViewModel
        let repository: MaintenanceTestRepository
        let session: MaintenanceTestVehicleSession
        let reminders: MaintenanceReminderRecorder
        let operation: ControllableMaintenanceOperation
    }

    enum Constants {
        static let firstVIN = "FENRTEST000000001"
        static let secondVIN = "FENRTEST000000002"
    }
}
