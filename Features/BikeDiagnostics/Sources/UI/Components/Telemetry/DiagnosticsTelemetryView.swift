import SwiftUI

struct DiagnosticsTelemetryView: View {
    let state: BikeDiagnosticsViewState
    let onRefresh: () -> Void

    var body: some View {
        List {
            ForEach(state.telemetrySections) { section in
                Section(section.title) {
                    switch section.style {
                    case .powerModes:
                        if state.powerModeConfigurations.isEmpty {
                            Text(verbatim: BikeDiagnosticsText.placeholder)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(state.powerModeConfigurations) {
                                DiagnosticsPowerModeRow(configuration: $0)
                            }
                        }
                    case .powerTier:
                        DiagnosticsPowerTierEvidenceView(metrics: section.metrics)
                    case .metrics:
                        ForEach(section.metrics) { DiagnosticsMetricRow(metric: $0) }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onRefresh) {
                    Label(DiagnosticsCopy.refresh, systemImage: "arrow.clockwise")
                        .frame(minWidth: Constants.minimumControlSize, minHeight: Constants.minimumControlSize)
                }
                .disabled(!state.isReadSnapshotEnabled)
            }
        }
    }

    private enum Constants {
        static let minimumControlSize: CGFloat = 44
    }
}
