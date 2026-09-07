import SwiftUI

public struct MaintenanceLogView: View {
    private let viewModel: MaintenanceViewModel
    private let onNavigation: (MaintenanceNavigationEvent) -> Void

    public init(
        viewModel: MaintenanceViewModel,
        onNavigation: @escaping (MaintenanceNavigationEvent) -> Void
    ) {
        self.viewModel = viewModel
        self.onNavigation = onNavigation
    }

    public var body: some View {
        MaintenanceListContent(
            state: viewModel.viewState,
            onAdd: { onNavigation(.show(.form(id: nil))) },
            onSelect: { onNavigation(.show(.detail(id: $0))) },
            onDelete: { viewModel.delete(id: $0) },
            onRefresh: { viewModel.refresh() }
        )
        .navigationTitle(.maintenanceTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onNavigation(.show(.form(id: nil)))
                } label: {
                    Label(.maintenanceAdd, systemImage: "plus")
                }
                .accessibilityIdentifier("maintenance.add")
                .disabled(viewModel.viewState.status != .loaded || viewModel.isMutating)
            }
        }
    }
}
