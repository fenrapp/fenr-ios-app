import SwiftUI

public struct AppSettingsScene: View {
    private let destination: AppSettingsDestination
    @ObservedObject private var viewModel: AppSettingsViewModel
    private let bikeLockModeTitle: String?
    private let isPresentationActive: Bool
    private let onNavigation: (AppSettingsNavigationEvent) -> Void
    private let accessory: () -> AnyView

    public init(
        destination: AppSettingsDestination,
        viewModel: AppSettingsViewModel,
        bikeLockModeTitle: String? = nil,
        isPresentationActive: Bool,
        onNavigation: @escaping (AppSettingsNavigationEvent) -> Void,
        accessory: @escaping () -> AnyView = { AnyView(EmptyView()) }
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.bikeLockModeTitle = bikeLockModeTitle
        self.isPresentationActive = isPresentationActive
        self.onNavigation = onNavigation
        self.accessory = accessory
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
            AppSettingsView(
                viewModel: viewModel,
                bikeLockModeTitle: bikeLockModeTitle,
                onNavigation: onNavigation,
                accessory: accessory
            )
        #if os(iOS)
        case .rideDisplay:
            RideDisplaySettingsView(viewModel: viewModel)
        case .navigation:
            NavigationSettingsView(viewModel: viewModel, onNavigation: onNavigation)
        case .navigationAppearance:
            NavigationAppearanceSettingsView(viewModel: viewModel)
        case .liveActivities:
            LiveActivitySettingsView(viewModel: viewModel)
        case .bikeModel:
            BikeModelSettingsView(viewModel: viewModel)
        #else
        case .rideDisplay, .navigation, .navigationAppearance, .bikeModel, .liveActivities:
            EmptyView()
        #endif
        }
    }

    private func synchronizePresentation() {
        guard ownsPresentationLifecycle else { return }
        if isPresentationActive {
            viewModel.start()
        } else {
            viewModel.stop()
        }
    }

    private var ownsPresentationLifecycle: Bool {
        destination == .overview
    }
}
