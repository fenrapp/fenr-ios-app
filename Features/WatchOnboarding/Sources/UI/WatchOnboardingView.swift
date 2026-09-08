import SwiftUI

public struct WatchOnboardingView: View {
    private let viewModel: WatchOnboardingViewModel

    public init(viewModel: WatchOnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        WatchOnboardingContentView(
            state: viewModel.viewState,
            select: viewModel.select,
            scan: viewModel.scan
        )
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
