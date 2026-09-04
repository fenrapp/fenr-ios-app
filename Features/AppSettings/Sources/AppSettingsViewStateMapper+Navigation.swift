import EnvironmentDomain
import Foundation
import SettingsDomain

extension AppSettingsViewStateMapper {
    func speedSource(
        _ source: SpeedSource,
        _ locationAuthorizationStatus: LocationAuthorizationStatus
    ) -> SpeedSourceSettingsViewState {
        SpeedSourceSettingsViewState(
            selection: .init(
                selectedID: source.rawValue,
                options: SpeedSource.allCases.map {
                    .init(id: $0.rawValue, title: speedSourceTitle($0))
                }
            ),
            description: speedSourceDescription(source),
            locationPermission: source.usesDeviceLocation
                ? locationPermission(locationAuthorizationStatus)
                : nil
        )
    }

    func navigationSettings(_ settings: RideNavigationSettings) -> NavigationSettingsViewState {
        NavigationSettingsViewState(
            showsGuidanceInFocus: settings.showsGuidanceInFocus,
            showsCompassRing: settings.showsCompassRing,
            showsRoadsInFocus: settings.showsRoadsInFocus,
            lineStyles: RideNavigationLineGroup.allCases.map { group in
                let appearance = settings.lineAppearances[group]
                return NavigationLineStyleViewData(
                    id: group.rawValue,
                    title: navigationLineGroupTitle(group),
                    color: NavigationColorComponents(
                        red: appearance.color.red,
                        green: appearance.color.green,
                        blue: appearance.color.blue
                    ),
                    thickness: .init(
                        selectedID: appearance.thickness.rawValue,
                        options: RideNavigationLineThickness.allCases.map {
                            .init(id: $0.rawValue, title: navigationLineThicknessTitle($0))
                        }
                    )
                )
            }
        )
    }

    private func navigationLineGroupTitle(
        _ group: RideNavigationLineGroup
    ) -> LocalizedStringResource {
        switch group {
        case .pendingRoute: .appSettingsNavigationLinePending
        case .activeSection: .appSettingsNavigationLineActive
        case .completedRoute: .appSettingsNavigationLineCompleted
        case .recording: .appSettingsNavigationLineRecording
        case .connector: .appSettingsNavigationLineConnector
        }
    }

    private func navigationLineThicknessTitle(
        _ thickness: RideNavigationLineThickness
    ) -> LocalizedStringResource {
        switch thickness {
        case .thin: .appSettingsNavigationThicknessThin
        case .regular: .appSettingsNavigationThicknessRegular
        case .thick: .appSettingsNavigationThicknessThick
        }
    }
}
