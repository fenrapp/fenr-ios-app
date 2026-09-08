import SwiftUI

public struct DashboardCardSectionDetailView: View {
    private let viewModel: DashboardCardSettingsViewModel
    private let sectionID: String

    public init(viewModel: DashboardCardSettingsViewModel, sectionID: String) {
        self.viewModel = viewModel
        self.sectionID = sectionID
    }

    public var body: some View {
        DashboardCardSectionDetailContent(
            section: viewModel.viewState.section(id: sectionID),
            setPageOrder: { viewModel.setPageOrder(ids: $0, sectionID: sectionID) },
            setPageVisibility: { viewModel.setPageVisibility($0, id: $1, sectionID: sectionID) }
        )
    }
}
