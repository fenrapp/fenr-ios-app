#if os(iOS)
import SwiftUI

struct LiveActivitySettingsContent: View {
    let state: LiveActivitySettingsViewState
    let setEnabled: (Bool) -> Void
    let setActivityEnabled: (Bool, String) -> Void
    let selectPresentation: (String, String) -> Void

    var body: some View {
        Form {
            Section {
                Toggle(.appSettingsLiveActivitiesEnabled, isOn: Binding(
                    get: { state.isEnabled },
                    set: { setEnabled($0) }
                ))
                .accessibilityIdentifier("settings.liveActivities.enabled")
            } footer: {
                Text(.appSettingsLiveActivitiesEnabledDetail)
            }
            ForEach(state.activities) { activity in
                LiveActivitySettingsSection(
                    activity: activity,
                    setEnabled: { setActivityEnabled($0, activity.id) },
                    selectPresentation: {
                        selectPresentation(activity.id, $0)
                    }
                )
                .disabled(!state.isEnabled)
            }
        }
        .navigationTitle(Text(.appSettingsLiveActivitiesTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
