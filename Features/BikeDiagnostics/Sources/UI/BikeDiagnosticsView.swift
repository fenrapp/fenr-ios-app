import DesignSystem
import SwiftUI

public struct BikeDiagnosticsView: View {
    @ObservedObject private var viewModel: BikeDiagnosticsViewModel
    private let onBatteryHealth: () -> Void
    private let onChangeBike: () -> Void

    public init(
        viewModel: BikeDiagnosticsViewModel,
        onBatteryHealth: @escaping () -> Void = {},
        onChangeBike: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onBatteryHealth = onBatteryHealth
        self.onChangeBike = onChangeBike
    }

    public var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                    HeaderView(
                        vin: viewModel.viewState.vin,
                        pin: viewModel.viewState.pin,
                        isVINEditingEnabled: viewModel.viewState.isVINEditingEnabled,
                        isConnectEnabled: viewModel.viewState.isConnectEnabled,
                        isDisconnectEnabled: viewModel.viewState.isDisconnectEnabled,
                        isPairRetryEnabled: viewModel.viewState.isPairRetryEnabled,
                        isBatteryHealthEnabled: viewModel.viewState.isBatteryHealthEnabled,
                        onVINChange: viewModel.vinChanged,
                        onConnect: viewModel.connectTapped,
                        onDisconnect: viewModel.disconnectTapped,
                        onPairRetry: viewModel.pairRetryTapped,
                        onBatteryHealth: onBatteryHealth
                    )

                    if landscape {
                        HStack(alignment: .top, spacing: Constants.columnSpacing) {
                            VStack(spacing: Constants.sectionSpacing) {
                                ConnectionPanelView(model: viewModel.viewState.connection)
                                BadgeRowView(badges: viewModel.viewState.badges)
                                MetricsGridView(metrics: viewModel.viewState.metrics)
                            }
                            .frame(maxWidth: Constants.primaryColumnMaxWidth)
                            VStack(spacing: Constants.sectionSpacing) {
                                RawFlagsView(flags: viewModel.viewState.rawFlags)
                                DebugEventsView(
                                    events: viewModel.viewState.debugEvents,
                                    hasLog: viewModel.viewState.hasDebugLog,
                                    logTextProvider: viewModel.debugLogText
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: Constants.sectionSpacing) {
                            ConnectionPanelView(model: viewModel.viewState.connection)
                            BadgeRowView(badges: viewModel.viewState.badges)
                            MetricsGridView(metrics: viewModel.viewState.metrics)
                            RawFlagsView(flags: viewModel.viewState.rawFlags)
                            DebugEventsView(
                                events: viewModel.viewState.debugEvents,
                                hasLog: viewModel.viewState.hasDebugLog,
                                logTextProvider: viewModel.debugLogText
                            )
                        }
                    }
                }
                .padding(Constants.screenPadding)
                .frame(maxWidth: Constants.contentMaxWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(DesignColor.groupedSurface)
            .dynamicTypeSize(.medium ... .large)
        }
        .navigationTitle("FENR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Change Bike", role: .destructive, action: onChangeBike)
            }
        }
        .task { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }

    private enum Constants {
        static let sectionSpacing = DesignSpace.small
        static let columnSpacing = DesignSpace.small
        static let screenPadding = DesignSpace.small
        static let contentMaxWidth: CGFloat = 1_180
        static let primaryColumnMaxWidth: CGFloat = 560
    }
}

#Preview("BikeDiagnostics") {
    BikeDiagnosticsView(viewModel: BikeDiagnosticsPreviewFactory.makeViewModel())
}
