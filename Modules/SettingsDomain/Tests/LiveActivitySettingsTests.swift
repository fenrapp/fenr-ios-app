import Foundation
import SettingsDomain
import Testing

@Suite("Live Activity preferences")
struct LiveActivitySettingsTests {
    @Test("Old settings preserve the existing detailed activities")
    func oldSettings() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(settings.liveActivities == .init())
        let partial = try JSONDecoder().decode(
            LiveActivitySettings.self, from: Data(#"{"isEnabled":false}"#.utf8)
        )
        #expect(!partial.isEnabled)
        #expect(partial.showsRiding && partial.showsCharging)
        #expect(partial.chargingDetailLevel == .detailed)
    }

    @Test("Disabled activities retain independent presentation preferences after decoding")
    func roundTrip() throws {
        let expected = LiveActivitySettings(
            isEnabled: false, showsRiding: false, chargingDetailLevel: .summary
        )
        let data = try JSONEncoder().encode(AppSettings(liveActivities: expected))
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.liveActivities == expected)
        #expect(decoded.scoped(toVIN: "FENRTEST000000001").liveActivities == expected)
    }
}
