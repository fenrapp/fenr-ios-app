import SwiftUI

public struct PowerModeAdvancedView: View {
    private let viewModel: PowerModeAdvancedViewModel

    public init(viewModel: PowerModeAdvancedViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        PowerModeAdvancedContent(
            state: viewModel.viewState,
            maps: viewModel.maps,
            send: viewModel.handle
        )
        .onAppear { viewModel.setVisible(true) }
        .onDisappear { viewModel.setVisible(false) }
    }
}
