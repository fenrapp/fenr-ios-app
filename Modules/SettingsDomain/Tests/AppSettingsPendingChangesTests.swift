import SettingsDomain
import Testing

@Suite("Optimistic settings commands")
struct AppSettingsPendingChangesTests {
    private let vin = "FENRTEST000000001"

    @Test("Rebases queued commands over unrelated changes and rolls back only the failed command")
    func rebasesAndRollsBackOneCommand() throws {
        var queue = AppSettingsPendingChanges()
        let original = AppSettings().scoped(toVIN: vin)
        queue.receive(.init(settings: original, revision: 0))
        let failed = try queue.enqueue(.navigation(.avoidsTolls(true)))
        let remaining = try queue.enqueue(.navigation(.mapOrientation(.northUp)))
        var external = original
        external.measurementSystem = .imperial
        queue.receive(.init(settings: external, revision: 1))
        #expect(queue.settings.rideNavigation.avoidsTolls)
        #expect(queue.settings.measurementSystem == .imperial)
        let rejected = queue.reject(id: failed)
        #expect(rejected)
        #expect(!queue.settings.rideNavigation.avoidsTolls)
        #expect(queue.settings.rideNavigation.mapOrientation == .northUp)
        #expect(queue.next?.id == remaining)
    }

    @Test("Confirmed commands cannot be reverted by a delayed observation")
    func ignoresDelayedObservation() throws {
        var queue = AppSettingsPendingChanges()
        let original = AppSettings().scoped(toVIN: vin)
        queue.receive(.init(settings: original, revision: 0))
        let id = try queue.enqueue(.measurementSystem(.imperial))
        var confirmed = original
        confirmed.measurementSystem = .imperial
        let completed = queue.complete(id: id, result: .changed(.init(settings: confirmed, revision: 2)))
        #expect(completed)
        queue.receive(.init(settings: original, revision: 1))
        #expect(queue.settings.measurementSystem == .imperial)
        #expect(queue.isEmpty)
    }

    @Test("Completing an earlier command preserves the later value for the same setting")
    func preservesPendingSameFieldIntent() throws {
        var queue = AppSettingsPendingChanges()
        let original = AppSettings().scoped(toVIN: vin)
        queue.receive(.init(settings: original, revision: 0))
        let first = try queue.enqueue(.measurementSystem(.imperial))
        let second = try queue.enqueue(.measurementSystem(.metric))
        var saved = original
        saved.measurementSystem = .imperial
        let completed = queue.complete(id: first, result: .changed(.init(settings: saved, revision: 1)))
        #expect(completed)
        #expect(queue.settings.measurementSystem == .metric)
        #expect(queue.next?.id == second)
    }

    @Test("A vehicle change clears pending changes and rejects late completions")
    func invalidatesVehicleChanges() throws {
        var queue = AppSettingsPendingChanges()
        let first = AppSettings().scoped(toVIN: vin)
        queue.receive(.init(settings: first, revision: 0))
        let id = try queue.enqueue(.measurementSystem(.imperial))
        let second = AppSettings().scoped(toVIN: "FENRTEST000000002")
        queue.receive(.init(settings: second, revision: 2))
        #expect(queue.isEmpty)
        let completed = queue.complete(id: id, result: .changed(.init(settings: first, revision: 1)))
        #expect(!completed)
        #expect(queue.settings == second)
    }

    @Test("A replay is required before accepting edits")
    func rejectsUnscopedEdits() {
        var queue = AppSettingsPendingChanges()
        #expect(throws: AppSettingsUpdateError.vehicleUnavailable) {
            try queue.enqueue(.measurementSystem(.metric))
        }
    }

    @Test("The security command reveals its card without replacing sibling configuration")
    func securityPreservesDashboardConfiguration() throws {
        var settings = AppSettings().scoped(toVIN: vin)
        settings.dashboardCardConfiguration.setSectionVisibility(false, id: .bikeLock)
        settings.dashboardCardConfiguration.setSectionVisibility(false, id: .efficiency)
        let updated = try AppSettingsChange.bikeLockSecurity(.pin).applying(to: settings)
        #expect(updated.bikeLockSettings(forVIN: vin).securityMode == .pin)
        #expect(updated.dashboardCardConfiguration.section(id: .bikeLock).isVisible)
        #expect(!updated.dashboardCardConfiguration.section(id: .efficiency).isVisible)
    }
}
