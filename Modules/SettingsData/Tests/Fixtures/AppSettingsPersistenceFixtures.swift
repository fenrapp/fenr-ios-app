import Foundation

enum AppSettingsPersistenceFixtures {
    static let settingsKey = "fenr.app.settings"
    static let scopedSettingsKey = "fenr.bike.settings.v1"

    static func settingsWithThickness(_ thickness: String, scoped: Bool) -> Data {
        let settings = """
        {
          "vin": "FENRTEST000000001",
          "speedSource": "gps",
          "measurementSystem": "imperial",
          "dashboardProgressBarMode": "speed",
          "dashboardProgressBarThickness": "\(thickness)"
        }
        """
        return Data((scoped ? "{\"FENRTEST000000001\":\(settings)}" : settings).utf8)
    }

    static let legacySettingsData = Data("""
    {
      "speedSource": "gps",
      "measurementSystem": "metric",
      "defaultBatteryPackCapacity": "sevenPointTwoKilowattHours",
      "batteryPackCapacitiesByVIN": {}
    }
    """.utf8)

    static let corruptSettingsData = Data("corrupt-settings".utf8)
}
