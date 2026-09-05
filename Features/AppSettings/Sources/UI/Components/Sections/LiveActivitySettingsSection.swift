import SwiftUI

struct LiveActivitySettingsSection: View {
    let activity: LiveActivitySettingsViewState.Activity
    let setEnabled: (Bool) -> Void
    let selectPresentation: (String) -> Void

    var body: some View {
        Section {
            Toggle(.appSettingsLiveActivitiesShow, isOn: Binding(
                get: { activity.isEnabled }, set: setEnabled
            ))
            .accessibilityIdentifier("settings.liveActivities." + activity.id)
            Picker(.appSettingsLiveActivitiesPresentation, selection: Binding(
                get: { activity.presentation.selectedID }, set: selectPresentation
            )) {
                ForEach(activity.presentation.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .disabled(!activity.isEnabled)
        } header: {
            Text(activity.title)
        } footer: {
            Text(activity.detail)
        }
    }
}
