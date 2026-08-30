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
            dashboardDeviceBatteryDisplayMode: .hidden,
            showsDashboardTemperatures: false,
            dashboardCardConfiguration: cardConfiguration,
            rideNavigation: RideNavigationSettings(
                avoidsTolls: true,
                avoidsHighways: true,
                preferredMapStyle: .satellite,
                mapOrientation: .northUp,
                miniMapPosition: MiniMapPosition(horizontalFraction: 0.28, verticalFraction: 0.73),
                miniMapScale: MiniMapScale(1.3),
                miniMapLayoutOrientation: .landscape
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
        #expect(await repository.load().dashboardDeviceBatteryDisplayMode == .iconAndText)
        #expect(!(await repository.load().showsDashboardTemperatures))
        #expect(await repository.load().dashboardCardConfiguration == .init())
        #expect(await repository.load().rideNavigation == .init())
        #expect(await repository.load().powerModeNamesByVIN.isEmpty)
    }

    @Test("Migrates legacy dashboard phone battery display modes")
    func migratesLegacyDeviceBatteryDisplayModes() async throws {
        for (rawValue, expected) in [
            ("icon", DashboardDeviceBatteryDisplayMode.iconAndText),
            ("text", DashboardDeviceBatteryDisplayMode.textOnly)
        ] {
            let defaults = makeDefaults()
            defaults.set(
                try JSONSerialization.data(withJSONObject: [
                    "dashboardDeviceBatteryDisplayMode": rawValue
                ]),
                forKey: "fenr.app.settings"
            )

            let settings = await UserDefaultsAppSettingsRepository(userDefaults: defaults).load()

            #expect(settings.dashboardDeviceBatteryDisplayMode == expected)
        }
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
        #expect(settings.rideNavigation.miniMapPosition == .topTrailing)
        #expect(settings.rideNavigation.miniMapScale == .initial)
        #expect(settings.rideNavigation.miniMapLayoutOrientation == .portrait)
    }

    @Test("Migrates a saved mini map corner to its normalized position")
    func migratesLegacyMiniMapCorner() async throws {
        let defaults = makeDefaults()
        defaults.set(
            try JSONSerialization.data(withJSONObject: [
                "rideNavigation": ["miniMapCorner": "bottomLeading"]
            ]),
            forKey: "fenr.app.settings"
        )

        let settings = await UserDefaultsAppSettingsRepository(userDefaults: defaults).load()

        #expect(settings.rideNavigation.miniMapPosition == MiniMapPosition(
            horizontalFraction: 0.15,
            verticalFraction: 0.65
        ))
    }

    @Test("Clamps a mini map position to normalized screen coordinates")
    func clampsMiniMapPositionToScreen() {
        let position = MiniMapPosition(horizontalFraction: -0.4, verticalFraction: 1.8)

        #expect(position.horizontalFraction == 0)
        #expect(position.verticalFraction == 1)
    }

    @Test("Clamps the persisted mini map scale to its supported range")
    func clampsMiniMapScale() {
        #expect(MiniMapScale(0.2).value == MiniMapScale.minimumValue)
        #expect(MiniMapScale(2).value == MiniMapScale.maximumValue)
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

    @Test("Persists Bike Lock security independently by bike")
    func persistsBikeLockSettingsByBike() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        var settings = AppSettings()
        settings.setBikeLockSettings(
            .init(securityMode: .pinAndFaceID),
            forVIN: "FENRTEST000000001"
        )

        await repository.save(settings)

        let reloaded = await UserDefaultsAppSettingsRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        ).load()
        #expect(
            reloaded.bikeLockSettings(forVIN: "FENRTEST000000001").securityMode
                == .pinAndFaceID
        )
        #expect(
            reloaded.bikeLockSettings(forVIN: "FENRTEST000000002").securityMode
                == .notConfigured
        )
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
