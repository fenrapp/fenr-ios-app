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
                                telemetryPanels
                            }
                            .frame(maxWidth: Constants.primaryColumnMaxWidth)
                            VStack(spacing: Constants.sectionSpacing) {
                                diagnosticPanels
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: Constants.sectionSpacing) {
                            telemetryPanels
                            diagnosticPanels
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
        .navigationTitle(.bikeDiagnosticsNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(.bikeDiagnosticsChangeBike, role: .destructive, action: onChangeBike)
            }
        }
        .sheet(item: exportBinding) { export in
            ActivityShareSheet(itemURL: export.fileURL)
        }
        .task { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }

    @ViewBuilder
    private var telemetryPanels: some View {
        ConnectionPanelView(model: viewModel.viewState.connection)
        BadgeRowView(badges: viewModel.viewState.badges)
        MetricsGridView(metrics: viewModel.viewState.metrics)
        MetricsGridView(
            title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionPowerTelemetry),
            metrics: viewModel.viewState.powerMetrics
        )
        MetricsGridView(
            title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionBatteryTelemetry),
            metrics: viewModel.viewState.batteryMetrics
        )
    }

    @ViewBuilder
    private var diagnosticPanels: some View {
        RawFlagsView(flags: viewModel.viewState.rawFlags)
        DebugEventsView(
            events: viewModel.viewState.debugEvents,
            hasLog: viewModel.viewState.hasDebugLog,
            logTextProvider: viewModel.debugLogText
        )
        BLETraceLogsView(
            sessions: viewModel.viewState.bleTraceSessions,
            error: viewModel.viewState.bleTraceError,
            onExport: viewModel.exportBLETraceSession,
            onDelete: viewModel.deleteBLETraceSession,
            onDeleteAll: viewModel.deleteAllBLETraceSessions
        )
    }

    private var exportBinding: Binding<BLETraceExportViewData?> {
        Binding(
            get: { viewModel.bleTraceExport },
            set: { value in
                if value == nil {
                    viewModel.clearBLETraceExport()
                }
            }
        )
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
