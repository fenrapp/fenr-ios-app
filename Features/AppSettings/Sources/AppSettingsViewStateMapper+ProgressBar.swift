import Foundation
import SettingsDomain

extension AppSettingsViewStateMapper {
    func progressBarThickness(_ settings: AppSettings) -> AppSettingsSelectionViewState {
        .init(
            selectedID: settings.dashboardProgressBarThickness.rawValue,
            options: DashboardProgressBarThickness.allCases.map {
                .init(id: $0.rawValue, title: progressBarThicknessTitle($0))
            }
        )
    }

    private func progressBarThicknessTitle(_ thickness: DashboardProgressBarThickness) -> LocalizedStringResource {
        switch thickness {
        case .regular: .appSettingsProgressBarThicknessRegular
        case .thick: .appSettingsProgressBarThicknessThick
        }
    }
}
