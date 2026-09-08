import Foundation
import SettingsDomain
import Testing

@Suite("App settings decoding")
struct AppSettingsDecodingTests {
    @Test("Decodes current and retired progress bar thickness values", arguments: [
        ("regular", DashboardProgressBarThickness.regular),
        ("thick", DashboardProgressBarThickness.thick),
        ("extraThick", DashboardProgressBarThickness.thick)
    ])
    func decodesProgressBarThickness(rawValue: String, expected: DashboardProgressBarThickness) throws {
        let data = Data("""
        { "dashboardProgressBarThickness": "\(rawValue)" }
        """.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.dashboardProgressBarThickness == expected)
        let encoded = try JSONEncoder().encode(settings.dashboardProgressBarThickness)
        #expect(try JSONDecoder().decode(String.self, from: encoded) == expected.rawValue)
        #expect(DashboardProgressBarThickness(rawValue: "extraThick") == nil)
    }

    @Test("Unknown progress bar thickness values remain decoding errors")
    func rejectsUnknownProgressBarThickness() {
        let data = Data("""
        { "dashboardProgressBarThickness": "unsupported" }
        """.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppSettings.self, from: data)
        }
    }

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
        #expect(settings.dashboardProgressBarThickness == .regular)
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
