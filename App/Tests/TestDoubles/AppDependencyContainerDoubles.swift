import BikeDomain
import Foundation
import SettingsDomain

actor EmptyBikeProfileRepository: BikeProfileRepository {
    func loadProfile() -> BikeProfile? {
        nil
    }

    func saveProfile(_: BikeProfile) {}

    func clearProfile() {}
}

actor EmptyAppSettingsRepository: AppSettingsRepository {
    func load() async -> AppSettings { .init() }
    func save(_: AppSettings) async {}
    func observe() async -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }
}
