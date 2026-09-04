import SettingsDomain

@MainActor
public extension AppSettingsViewModel {
    func setShowsGuidanceInFocus(_ isVisible: Bool) {
        updateNavigationSettings { $0.showsGuidanceInFocus = isVisible }
    }

    func setShowsCompassRing(_ isVisible: Bool) {
        updateNavigationSettings { $0.showsCompassRing = isVisible }
    }

    func setShowsRoadsInFocus(_ isVisible: Bool) {
        updateNavigationSettings { $0.showsRoadsInFocus = isVisible }
    }

    func setNavigationLineColor(
        groupID: String,
        red: Double,
        green: Double,
        blue: Double
    ) {
        guard let group = RideNavigationLineGroup(rawValue: groupID) else { return }
        updateNavigationSettings { navigation in
            var appearance = navigation.lineAppearances[group]
            appearance.color = RideNavigationLineColor(red: red, green: green, blue: blue)
            navigation.lineAppearances[group] = appearance
        }
    }

    func selectNavigationLineThickness(groupID: String, thicknessID: String) {
        guard let group = RideNavigationLineGroup(rawValue: groupID),
              let thickness = RideNavigationLineThickness(rawValue: thicknessID) else { return }
        updateNavigationSettings { navigation in
            var appearance = navigation.lineAppearances[group]
            appearance.thickness = thickness
            navigation.lineAppearances[group] = appearance
        }
    }
}
