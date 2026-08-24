@testable import BatteryHealth
import BikeDomain
import Foundation

@MainActor
func makeBatteryHealthViewModel(repository: any BikeBatteryHealthRepository) -> BatteryHealthViewModel {
    BatteryHealthViewModel(
        useCases: .init(
            startMonitoring: .init(repository: repository),
            stopMonitoring: .init(repository: repository),
            observeHealth: .init(repository: repository),
            observeCaptures: .init(repository: repository),
            observeSettings: .init(repository: FakeAppSettingsRepository())
        ),
        mapper: .init(formatter: makeBatteryHealthFormatter()),
        makeMapper: { _ in .init(formatter: makeBatteryHealthFormatter()) }
    )
}

@MainActor
func makeBatteryHealthFormatter(locale: Locale = .init(identifier: "en_US")) -> BatteryHealthFormatter {
    return BatteryHealthFormatter(
        locale: locale,
        measurementSystem: locale.measurementSystem
    )
}
