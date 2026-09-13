import Foundation
import SettingsDomain

extension AppSettingsViewStateMapper {
    func rideDisplayOverview(_ settings: AppSettings) -> RideDisplayOverviewViewState {
        let progress = dashboardProgressBarModeTitle(settings.dashboardProgressBarMode)
        let thickness = progressBarThickness(settings).options.first {
            $0.id == settings.dashboardProgressBarThickness.rawValue
        }?.title ?? .appSettingsUnavailable
        let bikeBattery = dashboardBatteryIndicatorModeTitle(settings.dashboardBatteryIndicatorMode)
        let phoneBattery = dashboardDeviceBatteryDisplayModeTitle(settings.dashboardDeviceBatteryDisplayMode)
        let temperatures = dashboardTemperatureDisplayModeTitle(settings.dashboardTemperatureDisplayMode)
        let hours: LocalizedStringResource = settings.showsBikeHours
            ? .appSettingsRideHoursVisible : .appSettingsRideHoursHidden
        return .init(
            progressBar: settings.dashboardProgressBarMode == .hidden ? progress : .appSettingsRideDisplayPairSummary(
                String(localized: progress), String(localized: thickness)
            ),
            batteryDisplay: .appSettingsRideBatterySummary(
                String(localized: bikeBattery), String(localized: phoneBattery)
            ),
            rideInformation: .appSettingsRideInformationSummary(
                String(localized: hours), String(localized: temperatures)
            ),
            speed: speedSourceTitle(settings.speedSource)
        )
    }

}
