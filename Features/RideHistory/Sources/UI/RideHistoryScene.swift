import SwiftUI

public struct RideHistoryScene: View {
    private let destination: RideHistoryDestination
    @ObservedObject private var viewModel: RideHistoryViewModel
    private let isPresentationActive: Bool
    private let onNavigation: (RideHistoryNavigationEvent) -> Void

    public init(
        destination: RideHistoryDestination,
        viewModel: RideHistoryViewModel,
        isPresentationActive: Bool,
        onNavigation: @escaping (RideHistoryNavigationEvent) -> Void
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.isPresentationActive = isPresentationActive
        self.onNavigation = onNavigation
    }

    public var body: some View {
        destinationView
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
            RideHistoryView(viewModel: viewModel, onNavigation: onNavigation)
        case .detail(let id):
            RideHistoryDetailView(viewModel: viewModel, rideID: id)
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
