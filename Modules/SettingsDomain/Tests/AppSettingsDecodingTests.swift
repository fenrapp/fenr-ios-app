import Foundation
import SettingsDomain
import Testing

@Suite("App settings decoding")
struct AppSettingsDecodingTests {
    @Test("Decodes legacy settings with dashboard display defaults")
    func decodesLegacySettings() throws {
        let data = Data("""
        {
          "speedSource": "gps",
          "measurementSystem": "metric",
          "defaultBatteryPackCapacity": "sevenPointTwoKilowattHours",
          "batteryPackCapacitiesByVIN": {}
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.dashboardProgressBarMode == .energy)
        #expect(settings.dashboardBatteryIndicatorMode == .percentage)
        #expect(settings.dashboardDeviceBatteryDisplayMode == .iconAndText)
        #expect(settings.dashboardTemperatureDisplayMode == .off)
        #expect(settings.dashboardCardConfiguration == .init())
        #expect(settings.rideNavigation == .init())
        #expect(settings.powerModeNamesByVIN.isEmpty)
    }

    @Test("Migrates the enabled legacy dashboard temperature setting to both")
    func migratesLegacyDashboardTemperatureSetting() throws {
        let data = Data("""
        { "showsDashboardTemperatures": true }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.dashboardTemperatureDisplayMode == .both)
    }

    @Test("Prefers the typed dashboard temperature mode over the legacy setting")
    func prefersTypedDashboardTemperatureSetting() throws {
        let data = Data("""
        {
          "dashboardTemperatureDisplayMode": "battery",
          "showsDashboardTemperatures": true
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.dashboardTemperatureDisplayMode == .battery)
    }

    @Test("Migrates legacy dashboard phone battery display modes", arguments: [
        ("icon", DashboardDeviceBatteryDisplayMode.iconAndText),
        ("text", DashboardDeviceBatteryDisplayMode.textOnly)
    ])
    func migratesLegacyDeviceBatteryDisplayModes(
        rawValue: String,
        expected: DashboardDeviceBatteryDisplayMode
    ) throws {
        let data = Data("""
        { "dashboardDeviceBatteryDisplayMode": "\(rawValue)" }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.dashboardDeviceBatteryDisplayMode == expected)
    }
}
