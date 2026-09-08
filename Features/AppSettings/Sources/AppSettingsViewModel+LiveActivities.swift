import SettingsDomain

@MainActor
public extension AppSettingsViewModel {
    func setLiveActivitiesEnabled(_ isEnabled: Bool) {
        applyAndSave(.liveActivities(.isEnabled(isEnabled)))
    }

    func setLiveActivityEnabled(_ isEnabled: Bool, id: String) {
        switch id {
        case "riding": applyAndSave(.liveActivities(.showsRiding(isEnabled)))
        case "charging": applyAndSave(.liveActivities(.showsCharging(isEnabled)))
        default: return
        }
    }

    func selectLiveActivityPresentation(id: String, presentationID: String) {
        guard let level = LiveActivitySettings.DetailLevel(rawValue: presentationID) else { return }
        switch id {
        case "riding": applyAndSave(.liveActivities(.ridingDetailLevel(level)))
        case "charging": applyAndSave(.liveActivities(.chargingDetailLevel(level)))
        default: return
        }
    }
}
