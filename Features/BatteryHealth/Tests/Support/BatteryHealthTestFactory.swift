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
    let voltageFormatter = MeasurementFormatter()
    voltageFormatter.locale = locale
    voltageFormatter.unitOptions = .providedUnit
    voltageFormatter.numberFormatter.maximumFractionDigits = 1

    let temperatureFormatter = MeasurementFormatter()
    temperatureFormatter.locale = locale
    temperatureFormatter.unitOptions = .naturalScale
    temperatureFormatter.numberFormatter.maximumFractionDigits = 1

    let currentFormatter = MeasurementFormatter()
    currentFormatter.locale = locale
    currentFormatter.unitOptions = .providedUnit
    currentFormatter.numberFormatter.maximumFractionDigits = 1

    let powerFormatter = MeasurementFormatter()
    powerFormatter.locale = locale
    powerFormatter.unitOptions = .naturalScale
    powerFormatter.numberFormatter.maximumFractionDigits = 1

    return BatteryHealthFormatter(
        locale: locale,
        measurementFormatters: .init(
            voltageFormatter: voltageFormatter,
            temperatureFormatter: temperatureFormatter,
            currentFormatter: currentFormatter,
            powerFormatter: powerFormatter,
            temperatureUnit: .fahrenheit
        )
    )
}
