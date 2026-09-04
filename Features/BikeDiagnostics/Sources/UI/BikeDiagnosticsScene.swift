import SwiftUI

public struct BikeDiagnosticsScene: View {
    private let destination: BikeDiagnosticsDestination
    @ObservedObject private var viewModel: BikeDiagnosticsViewModel
    private let isPresentationActive: Bool
    private let onNavigation: (BikeDiagnosticsNavigationEvent) -> Void

    public init(
        destination: BikeDiagnosticsDestination,
        viewModel: BikeDiagnosticsViewModel,
        isPresentationActive: Bool,
        onNavigation: @escaping (BikeDiagnosticsNavigationEvent) -> Void
    ) {
        self.destination = destination
        self.viewModel = viewModel
        self.isPresentationActive = isPresentationActive
        self.onNavigation = onNavigation
    }

    public var body: some View {
        destinationView
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: exportBinding) { export in
                ActivityShareSheet(itemURL: export.fileURL)
            }
            .task { synchronizePresentation() }
            .onChange(of: isPresentationActive) { synchronizePresentation() }
            .onDisappear {
                if ownsPresentationLifecycle, !isPresentationActive {
                    viewModel.setPresentationActive(false)
                }
            }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .overview:
            DiagnosticsOverviewView(
                state: viewModel.viewState,
                onNavigate: { onNavigation(.show($0)) },
                onBatteryHealth: { onNavigation(.openBatteryHealth) }
            )
        case .connection:
            DiagnosticsConnectionView(
                state: viewModel.viewState,
                onReconnect: viewModel.reconnectTapped,
                onRetry: viewModel.pairRetryTapped,
                onDisconnect: viewModel.disconnectTapped
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
                onToggleCapture: viewModel.toggleBLETraceCapture,
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

    private func synchronizePresentation() {
        guard ownsPresentationLifecycle else { return }
        viewModel.setPresentationActive(isPresentationActive)
    }

    private var ownsPresentationLifecycle: Bool {
        destination == .overview
    }
}
