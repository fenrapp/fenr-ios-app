import DesignSystem
import SwiftUI

public struct WatchDashboardView: View {
    @ObservedObject private var viewModel: WatchDashboardViewModel
    private let onNavigation: (WatchDashboardNavigationEvent) -> Void

    public init(
        viewModel: WatchDashboardViewModel,
        onNavigation: @escaping (WatchDashboardNavigationEvent) -> Void
    ) {
        self.viewModel = viewModel
        self.onNavigation = onNavigation
    }

    public var body: some View {
        Group {
            switch viewModel.viewState.mode {
            case .unavailable(let detail): unavailable(detail: detail)
            case .ride:
                WatchRideDashboardContent(
                    state: viewModel.viewState,
                    onChangeBike: { onNavigation(.changeBike) }
                )
            case .charging:
                WatchChargingDashboardContent(
                    state: viewModel.viewState,
                    onChangeBike: { onNavigation(.changeBike) }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { onNavigation(.openSettings) }, label: {
                    Image(systemName: "gearshape")
                })
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
                WatchChangeBikeButton(action: { onNavigation(.changeBike) })
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
            onNavigation: { _ in }
        )
    }
}
#endif
