import SwiftUI

public struct MaintenanceScene: View {
    private let destination: MaintenanceDestination
    @ObservedObject private var viewModel: MaintenanceViewModel
    private let isPresentationActive: Bool
    private let onNavigation: (MaintenanceNavigationEvent) -> Void

    public init(
        destination: MaintenanceDestination,
        viewModel: MaintenanceViewModel,
        isPresentationActive: Bool,
        onNavigation: @escaping (MaintenanceNavigationEvent) -> Void
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.isPresentationActive = isPresentationActive
        self.onNavigation = onNavigation
    }

    public var body: some View {
        destinationView
            .alert(.maintenanceErrorTitle, isPresented: errorBinding) {
                Button(.maintenanceOK) { viewModel.dismissError() }
            } message: {
                Text(viewModel.viewState.errorMessage ?? String(localized: .maintenanceGenericError))
            }
            .task { synchronizePresentation() }
            .onChange(of: isPresentationActive) { synchronizePresentation() }
            .onDisappear {
                if destination == .overview, !isPresentationActive { viewModel.stop() }
            }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .overview:
            MaintenanceLogView(viewModel: viewModel, onNavigation: onNavigation)
        case .detail(let id):
            MaintenanceDetailView(viewModel: viewModel, entryID: id, onNavigation: onNavigation)
        case .form(let id):
            MaintenanceFormView(viewModel: viewModel, entryID: id, onNavigation: onNavigation)
        }
    }

    private func synchronizePresentation() {
        guard destination == .overview else { return }
        if isPresentationActive { viewModel.start() } else { viewModel.stop() }
    }

    private var errorBinding: Binding<Bool> {
        .init(
            get: { viewModel.viewState.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }
}
