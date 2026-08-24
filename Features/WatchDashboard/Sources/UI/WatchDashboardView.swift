import DesignSystem
import SwiftUI

public struct WatchDashboardView: View {
    @ObservedObject private var viewModel: WatchDashboardViewModel
    private let onChangeBike: () -> Void
    private let onOpenSettings: () -> Void

    public init(
        viewModel: WatchDashboardViewModel,
        onChangeBike: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onChangeBike = onChangeBike
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        Group {
            switch viewModel.viewState.mode {
            case .unavailable(let detail): unavailable(detail: detail)
            case .ride:
                WatchRideDashboardContent(
                    state: viewModel.viewState,
                    onChangeBike: onChangeBike
                )
            case .charging:
                WatchChargingDashboardContent(
                    state: viewModel.viewState,
                    onChangeBike: onChangeBike
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private func unavailable(detail: String) -> some View {
        VStack(spacing: DesignSpace.small) {
            ContentUnavailableView(
                "Waiting for bike",
                systemImage: "bolt.horizontal.circle",
                description: Text(detail)
            )
            WatchChangeBikeButton(action: onChangeBike)
        }
    }
}

#if DEBUG
#Preview("Ride") {
    NavigationStack {
        WatchDashboardView(
            viewModel: WatchDashboardPreviewFactory.ride(),
            onChangeBike: {},
            onOpenSettings: {}
        )
    }
}
#endif
