import SettingsDomain

@MainActor
public extension AppSettingsViewModel {
    func setShowsGuidanceInFocus(_ isVisible: Bool) {
        applyAndSave(.navigation(.showsGuidanceInFocus(isVisible)))
    }

    func setShowsCompassRing(_ isVisible: Bool) {
        applyAndSave(.navigation(.showsCompassRing(isVisible)))
    }

    func setShowsRoadsInFocus(_ isVisible: Bool) {
        applyAndSave(.navigation(.showsRoadsInFocus(isVisible)))
    }

    func setNavigationLineColor(
        groupID: String,
        red: Double,
        green: Double,
        blue: Double
    ) {
        guard let group = RideNavigationLineGroup(rawValue: groupID) else { return }
        applyAndSave(.navigation(.lineColor(
            group: group,
            color: RideNavigationLineColor(red: red, green: green, blue: blue)
        )))
    }

    func selectNavigationLineThickness(groupID: String, thicknessID: String) {
        guard let group = RideNavigationLineGroup(rawValue: groupID),
              let thickness = RideNavigationLineThickness(rawValue: thicknessID) else { return }
        applyAndSave(.navigation(.lineThickness(group: group, thickness: thickness)))
    }
}
