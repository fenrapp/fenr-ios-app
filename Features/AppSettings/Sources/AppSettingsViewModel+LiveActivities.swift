import SettingsDomain

@MainActor
public extension AppSettingsViewModel {
    func setLiveActivitiesEnabled(_ isEnabled: Bool) {
        updateLiveActivitySettings { $0.isEnabled = isEnabled }
    }

    func setLiveActivityEnabled(_ isEnabled: Bool, id: String) {
        switch id {
        case "riding": updateLiveActivitySettings { $0.showsRiding = isEnabled }
        case "charging": updateLiveActivitySettings { $0.showsCharging = isEnabled }
        default: return
        }
    }

    func selectLiveActivityPresentation(id: String, presentationID: String) {
        guard let level = LiveActivitySettings.DetailLevel(rawValue: presentationID) else { return }
        switch id {
        case "riding": updateLiveActivitySettings { $0.ridingDetailLevel = level }
        case "charging": updateLiveActivitySettings { $0.chargingDetailLevel = level }
        default: return
        }
    }
}
