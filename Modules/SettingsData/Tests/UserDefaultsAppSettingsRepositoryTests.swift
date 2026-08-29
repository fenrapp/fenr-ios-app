@preconcurrency import Foundation
import SettingsData
import SettingsDomain
import Testing

@MainActor
@Suite("App settings persistence")
struct UserDefaultsAppSettingsRepositoryTests {
    @Test("Returns defaults until settings are saved")
    func returnsDefaults() async {
        let repository = UserDefaultsAppSettingsRepository(userDefaults: makeDefaults())
        #expect(await repository.load() == AppSettings())
    }

    @Test("Persists selected dashboard, speed, units, and battery settings")
    func persistsSettings() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        var cardConfiguration = DashboardCardConfiguration()
        cardConfiguration.setSectionOrder([
            .range, .navigation, .currentTrip, .efficiency, .systemHealth, .rideDynamics
        ])
        cardConfiguration.setSectionVisibility(false, id: .efficiency)
        let expected = AppSettings(
            speedSource: .hybrid,
            dashboardProgressBarMode: .speed,
            dashboardBatteryIndicatorMode: .estimatedRange,
            dashboardDeviceBatteryDisplayMode: .text,
            showsDashboardTemperatures: false,
            dashboardCardConfiguration: cardConfiguration,
            rideNavigation: RideNavigationSettings(
                avoidsTolls: true,
                avoidsHighways: true,
                preferredMapStyle: .satellite,
                mapOrientation: .northUp,
                miniMapCorner: .bottomLeading
            ),
            measurementSystem: .imperial,
            batteryPackCapacity: .sixPointEightKilowattHours
        )

        await repository.save(expected)

        let reloadedRepository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        )
        #expect(await reloadedRepository.load() == expected)
    }

    @Test("Decodes legacy settings with dashboard display defaults")
    func decodesLegacySettings() async throws {
        let suiteName = makeSuiteName()
        let defaults = makeDefaults(suiteName: suiteName)
        defaults.set(
            try JSONSerialization.data(withJSONObject: [
                "speedSource": "gps",
                "measurementSystem": "metric",
                "defaultBatteryPackCapacity": "sevenPointTwoKilowattHours",
                "batteryPackCapacitiesByVIN": [:]
            ]),
            forKey: "fenr.app.settings"
        )

        let repository = UserDefaultsAppSettingsRepository(userDefaults: defaults)

        #expect(await repository.load().dashboardProgressBarMode == .energy)
        #expect(await repository.load().dashboardBatteryIndicatorMode == .percentage)
        #expect(await repository.load().dashboardDeviceBatteryDisplayMode == .icon)
        #expect(!(await repository.load().showsDashboardTemperatures))
        #expect(await repository.load().dashboardCardConfiguration == .init())
        #expect(await repository.load().rideNavigation == .init())
        #expect(await repository.load().powerModeNamesByVIN.isEmpty)
    }

    @Test("Decodes legacy ride navigation settings with heading up")
    func decodesLegacyRideNavigationSettings() async throws {
        let suiteName = makeSuiteName()
        let defaults = makeDefaults(suiteName: suiteName)
        defaults.set(
            try JSONSerialization.data(withJSONObject: [
                "rideNavigation": [
                    "avoidsTolls": true,
                    "avoidsHighways": false,
                    "preferredMapStyle": "standard"
                ]
            ]),
            forKey: "fenr.app.settings"
        )

        let settings = await UserDefaultsAppSettingsRepository(userDefaults: defaults).load()

        #expect(settings.rideNavigation.mapOrientation == .headingUp)
        #expect(settings.rideNavigation.miniMapCorner == .topTrailing)
    }

    @Test("Persists power mode names independently by bike and map")
    func persistsPowerModeNames() async throws {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        var settings = AppSettings()
        try settings.setPowerModeName(
            try PowerModeName("ECO"),
            forVIN: "FENRTEST000000001",
            mapIndex: 0
        )
        try settings.setPowerModeName(
            try PowerModeName("Enduro"),
            forVIN: "FENRTEST000000002",
            mapIndex: 1
        )

        await repository.save(settings)

        let reloaded = await UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        ).load()
        #expect(reloaded.powerModeName(forVIN: "FENRTEST000000001", mapIndex: 0)?.value == "ECO")
        #expect(reloaded.powerModeName(forVIN: "FENRTEST000000002", mapIndex: 1)?.value == "Enduro")
        #expect(reloaded.powerModeName(forVIN: "FENRTEST000000001", mapIndex: 1) == nil)
    }

    @Test("Does not notify observers when the saved settings are unchanged")
    func skipsDuplicateSettingsNotifications() async {
        let repository = UserDefaultsAppSettingsRepository(userDefaults: makeDefaults())
        let stream = await repository.observe()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()
        let metric = AppSettings(measurementSystem: .metric)
        let imperial = AppSettings(measurementSystem: .imperial)

        await repository.save(metric)
        #expect(await iterator.next() == metric)
        await repository.save(metric)
        await repository.save(imperial)

        #expect(await iterator.next() == imperial)
    }

    nonisolated private func makeSuiteName() -> String {
        "UserDefaultsAppSettingsRepositoryTests.\(UUID().uuidString)"
    }

    nonisolated private func makeDefaults(
        suiteName: String = "UserDefaultsAppSettingsRepositoryTests.\(UUID().uuidString)",
        clearsDomain: Bool = true
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        if clearsDomain {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
