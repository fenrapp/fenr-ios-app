import Foundation
import SettingsDomain

extension AppSettingsViewStateMapper {
    func liveActivities(_ settings: LiveActivitySettings) -> LiveActivitySettingsViewState {
        .init(
            isEnabled: settings.isEnabled,
            summary: settings.isEnabled && (settings.showsRiding || settings.showsCharging)
                ? .appSettingsLiveActivitiesSummary : .appSettingsLiveActivitiesOff,
            activities: [
                .init(
                    id: "riding", title: .appSettingsLiveActivitiesRiding,
                    detail: .appSettingsLiveActivitiesRidingDetail,
                    isEnabled: settings.showsRiding,
                    presentation: liveActivityPresentation(settings.ridingDetailLevel)
                ),
                .init(
                    id: "charging", title: .appSettingsLiveActivitiesCharging,
                    detail: .appSettingsLiveActivitiesChargingDetail,
                    isEnabled: settings.showsCharging,
                    presentation: liveActivityPresentation(settings.chargingDetailLevel)
                )
            ]
        )
    }

    private func liveActivityPresentation(
        _ level: LiveActivitySettings.DetailLevel
    ) -> AppSettingsSelectionViewState {
        .init(selectedID: level.rawValue, options: LiveActivitySettings.DetailLevel.allCases.map {
            .init(id: $0.rawValue, title: $0 == .summary
                ? .appSettingsLiveActivitiesViewSummary : .appSettingsLiveActivitiesViewDetailed)
        })
    }
}
