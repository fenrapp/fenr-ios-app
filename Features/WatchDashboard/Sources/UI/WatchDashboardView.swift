import SwiftUI

public struct WatchDashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    private let viewModel: WatchDashboardViewModel

    public init(viewModel: WatchDashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: Constants.ambientRefreshInterval)) { _ in
            content
        }
        .opacity(isLuminanceReduced ? Constants.dimmedOpacity : 1)
        .transaction { if isLuminanceReduced { $0.animation = nil } }
        .onAppear { viewModel.start() }
        .onChange(of: scenePhase) {
            if scenePhase == .background { viewModel.stop() } else { viewModel.start() }
        }
        .onDisappear { viewModel.stop() }
    }

    private var content: some View {
        Group {
            if viewModel.viewState.hasData {
                if viewModel.viewState.isCharging {
                    WatchChargingDashboardContent(state: viewModel.viewState)
                } else {
                    WatchRideDashboardContent(state: viewModel.viewState)
                }
            } else {
                ContentUnavailableView(
                    String(localized: .watchCompanionTitle),
                    systemImage: "iphone.and.arrow.forward",
                    description: Text(verbatim: viewModel.viewState.status)
                )
            }
        }
    }

    private enum Constants {
        static let ambientRefreshInterval = 15.0
        static let dimmedOpacity = 0.65
    }
}
