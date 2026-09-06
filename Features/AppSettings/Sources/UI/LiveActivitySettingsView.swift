#if os(iOS)
import SwiftUI

public struct LiveActivitySettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel

    public init(viewModel: AppSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        LiveActivitySettingsContent(
            state: viewModel.viewState.liveActivities,
            setEnabled: viewModel.setLiveActivitiesEnabled,
            setActivityEnabled: { viewModel.setLiveActivityEnabled($0, id: $1) },
            selectPresentation: { viewModel.selectLiveActivityPresentation(id: $0, presentationID: $1) }
        )
    }
}
#endif
