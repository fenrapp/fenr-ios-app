import SwiftUI

public struct BikeDiagnosticsScene: View {
    private let destination: BikeDiagnosticsDestination
    @ObservedObject private var viewModel: BikeDiagnosticsViewModel
    private let onNavigate: (BikeDiagnosticsDestination) -> Void
    private let onBatteryHealth: () -> Void
    private let onChangeBike: () -> Void

    public init(
        destination: BikeDiagnosticsDestination,
        viewModel: BikeDiagnosticsViewModel,
        onNavigate: @escaping (BikeDiagnosticsDestination) -> Void = { _ in },
        onBatteryHealth: @escaping () -> Void = {},
        onChangeBike: @escaping () -> Void = {}
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.onNavigate = onNavigate
        self.onBatteryHealth = onBatteryHealth
        self.onChangeBike = onChangeBike
    }

    public var body: some View {
        destinationView
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: exportBinding) { export in
                ActivityShareSheet(itemURL: export.fileURL)
            }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .overview:
            DiagnosticsOverviewView(
                state: viewModel.viewState,
                onNavigate: onNavigate,
                onBatteryHealth: onBatteryHealth,
                onChangeBike: onChangeBike
            )
        case .connection:
            DiagnosticsConnectionView(
                state: viewModel.viewState,
                onReconnect: viewModel.reconnectTapped,
                onRetry: viewModel.pairRetryTapped,
                onDisconnect: viewModel.disconnectTapped,
                onChangeBike: onChangeBike
            )
        case .telemetry:
            DiagnosticsTelemetryView(
                state: viewModel.viewState,
                onRefresh: viewModel.readSnapshotTapped
            )
        case .status:
            DiagnosticsStatusView(state: viewModel.viewState)
        case .events:
            DiagnosticsEventsView(
                state: viewModel.viewState,
                logTextProvider: viewModel.debugLogText,
                onClear: viewModel.clearDebugEvents
            )
        case .bleLogs:
            DiagnosticsBLELogsView(
                state: viewModel.viewState,
                onExport: viewModel.exportBLETraceSession,
                onDelete: viewModel.deleteBLETraceSession,
                onDeleteAll: viewModel.deleteAllBLETraceSessions
            )
        }
    }

    private var exportBinding: Binding<BLETraceExportViewData?> {
        Binding(
            get: { viewModel.bleTraceExport },
            set: { value in
                if value == nil { viewModel.clearBLETraceExport() }
            }
        )
    }
}
