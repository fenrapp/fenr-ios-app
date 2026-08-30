import Foundation

enum AppSettingsPersistenceFixtures {
    static let settingsKey = "fenr.app.settings"

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
