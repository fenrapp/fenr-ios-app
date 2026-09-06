import SwiftUI

public struct DashboardCardSettingsView: View {
    @ObservedObject private var viewModel: DashboardCardSettingsViewModel
    private let onNavigation: (DashboardCardSettingsNavigationEvent) -> Void

    public init(
        viewModel: DashboardCardSettingsViewModel,
        onNavigation: @escaping (DashboardCardSettingsNavigationEvent) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onNavigation = onNavigation
    }

    public var body: some View {
        DashboardCardSettingsContent(
            state: viewModel.viewState,
            setSectionOrder: { viewModel.setSectionOrder(ids: $0) },
            setSectionVisibility: { viewModel.setSectionVisibility($0, id: $1) },
            selectSection: { onNavigation(.show(.section(id: $0))) }
        )
    }
}
