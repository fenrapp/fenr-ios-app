import Foundation
import MaintenanceDomain
import MaintenanceLog
import MeasurementPresentation
import VehicleSession

@MainActor
struct MaintenanceDependencyContainer {
    private let reminderScheduler: any MaintenanceReminderScheduling

    init(reminderScheduler: any MaintenanceReminderScheduling) {
        self.reminderScheduler = reminderScheduler
    }

    func makeViewModel(
        repository: any MaintenanceRepository,
        vehicleSession: any VehicleSessionService
    ) -> MaintenanceViewModel {
        let locale = Locale.autoupdatingCurrent
        let now: @Sendable () -> Date = Date.init
        return MaintenanceViewModel(
            useCases: .init(
                loadEntries: .init(repository: repository),
                saveEntry: .init(repository: repository),
                deleteEntry: .init(repository: repository)
            ),
            vehicleSession: vehicleSession,
            mapper: MaintenanceViewStateMapper(
                locale: locale,
                now: now,
                textFormatter: VehicleMeasurementTextFormatter(locale: locale)
            ),
            draftMapper: MaintenanceFormDraftMapper(
                numberParser: MaintenanceNumberParser(locale: locale),
                locale: locale,
                calendar: .autoupdatingCurrent,
                now: now
            ),
            reminderScheduler: reminderScheduler,
            now: now
        )
    }
}
