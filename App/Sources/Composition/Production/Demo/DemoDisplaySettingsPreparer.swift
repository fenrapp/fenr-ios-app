import Foundation
import SettingsDomain

@MainActor
struct DemoDisplaySettingsPreparer {
    let defaults: UserDefaults
    let settings: any AppSettingsRepository
    let vin: String

    func prepare() async throws {
        guard !defaults.bool(forKey: Constants.preparedKey) else { return }
        _ = try await settings.update(expectedVIN: vin, change: .showsBikeHours(true))
        defaults.set(true, forKey: Constants.preparedKey)
    }

    private enum Constants {
        static let preparedKey = "demo.display.hours.v1"
    }
}
