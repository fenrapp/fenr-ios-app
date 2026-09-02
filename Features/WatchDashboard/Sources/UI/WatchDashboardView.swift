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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text(.watchDashboardSettings))
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private func unavailable(detail: String) -> some View {
        List {
            Section {
                ContentUnavailableView(
                    String(localized: .watchDashboardWaitingForBike),
                    systemImage: "bolt.horizontal.circle",
                    description: Text(verbatim: detail)
                )
                WatchChangeBikeButton(action: onChangeBike)
            }

            if !viewModel.debugEvents.isEmpty {
                Section {
                    ForEach(viewModel.debugEvents) { event in
                        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                            Text(verbatim: event.title)
                                .font(.caption2.weight(.semibold))
                            Text(verbatim: event.detail)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                } header: {
                    Text(.watchDashboardDebug)
                }
            }
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
