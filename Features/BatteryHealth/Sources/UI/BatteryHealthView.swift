import SwiftUI

public struct BatteryHealthView: View {
    private let viewModel: BatteryHealthViewModel

    public init(viewModel: BatteryHealthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        BatteryHealthScene(
            destination: .overview,
            viewModel: viewModel,
            isPresentationActive: true,
            onNavigation: { _ in }
        )
    }
}

#Preview("Battery Health") {
    NavigationStack {
        BatteryHealthView(viewModel: BatteryHealthPreviewFactory.makeViewModel())
    }
}
