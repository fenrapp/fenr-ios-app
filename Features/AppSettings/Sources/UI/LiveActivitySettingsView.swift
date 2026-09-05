#if os(iOS)
import SwiftUI

public struct LiveActivitySettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel

    public init(viewModel: AppSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                Toggle(.appSettingsLiveActivitiesEnabled, isOn: Binding(
                    get: { viewModel.viewState.liveActivities.isEnabled },
                    set: { viewModel.setLiveActivitiesEnabled($0) }
                ))
                .accessibilityIdentifier("settings.liveActivities.enabled")
            } footer: {
                Text(.appSettingsLiveActivitiesEnabledDetail)
            }
            ForEach(viewModel.viewState.liveActivities.activities) { activity in
                LiveActivitySettingsSection(
                    activity: activity,
                    setEnabled: { viewModel.setLiveActivityEnabled($0, id: activity.id) },
                    selectPresentation: {
                        viewModel.selectLiveActivityPresentation(id: activity.id, presentationID: $0)
                    }
                )
                .disabled(!viewModel.viewState.liveActivities.isEnabled)
            }
        }
        .navigationTitle(Text(.appSettingsLiveActivitiesTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
