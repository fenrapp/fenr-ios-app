import BikeDomain
import Foundation
import SettingsDomain

struct PowerModeMapSelectionMapper: Sendable {
    func map(settings: AppSettings, profile: BikeProfile?, selected: Int) -> [PowerModeMapViewData] {
        let names = settings.powerModeNames(forVIN: profile?.vin)
        return (0 ... 4).map { index in
            let name = names[index]?.value
            return .init(
                id: index, title: name ?? String(index + 1),
                accessibilityLabel: name.map {
                    String(localized: .powerModeSettingsNamedMapAccessibility(index + 1, $0))
                }
                    ?? String(localized: .powerModeSettingsMapAccessibility(index + 1)),
                isSelected: index == selected
            )
        }
    }
}
