import SwiftUI

public struct DashboardCardSettingsScene: View {
    private let destination: DashboardCardSettingsDestination
    private let viewModel: DashboardCardSettingsViewModel
    private let isPresentationActive: Bool
    private let onNavigation: (DashboardCardSettingsNavigationEvent) -> Void

    public init(
        destination: DashboardCardSettingsDestination,
        viewModel: DashboardCardSettingsViewModel,
        isPresentationActive: Bool,
        onNavigation: @escaping (DashboardCardSettingsNavigationEvent) -> Void
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.isPresentationActive = isPresentationActive
        self.onNavigation = onNavigation
    }

    public var body: some View {
        destinationView
            .alert(
                Text(.dashboardCardSettingsSaveErrorTitle),
                isPresented: Binding(
                    get: { viewModel.settingsSaveError != nil },
                    set: { if !$0 { viewModel.dismissSettingsSaveError() } }
                )
            ) {
                Button(.dashboardCardSettingsSaveErrorDismiss) { viewModel.dismissSettingsSaveError() }
            } message: {
                Text(verbatim: viewModel.settingsSaveError ?? "")
            }
            .task { synchronizePresentation() }
            .onChange(of: isPresentationActive) { synchronizePresentation() }
            .onDisappear {
                if ownsPresentationLifecycle, !isPresentationActive { viewModel.stop() }
            }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .overview:
            DashboardCardSettingsView(viewModel: viewModel, onNavigation: onNavigation)
        case .section(let id):
            DashboardCardSectionDetailView(viewModel: viewModel, sectionID: id)
        }
    }

    private func synchronizePresentation() {
        guard ownsPresentationLifecycle else { return }
        if isPresentationActive { viewModel.start() } else { viewModel.stop() }
    }

    private var ownsPresentationLifecycle: Bool {
        destination == .overview
    }
}
