import DesignSystem
import SwiftUI

struct DiagnosticsOverviewView: View {
    let state: BikeDiagnosticsViewState
    let onNavigate: (BikeDiagnosticsDestination) -> Void
    let onBatteryHealth: () -> Void
    let onChangeBike: () -> Void

    var body: some View {
        List {
            Section(DiagnosticsCopy.connection) {
                ListNavigationRow(
                    title: state.connection.status,
                    subtitle: state.connection.detail,
                    systemImage: statusImage,
                    tint: statusColor,
                    trailingValue: state.connection.rssi,
                    action: { onNavigate(.connection) }
                )
            }

            Section(DiagnosticsCopy.liveSummary) {
                ForEach(state.overviewMetrics) { DiagnosticsMetricRow(metric: $0) }
                if !state.badges.isEmpty {
                    LabeledContent(DiagnosticsCopy.state) {
                        Text(state.badges.map(\.title).joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section {
                DiagnosticsDestinationRow(
                    title: DiagnosticsCopy.batteryHealth,
                    subtitle: DiagnosticsCopy.batteryHealthDetail,
                    systemImage: "battery.100percent",
                    tint: DesignColor.positive,
                    action: onBatteryHealth
                )
                .disabled(!state.isBatteryHealthEnabled)
            } footer: {
                if !state.isBatteryHealthEnabled {
                    Text(verbatim: DiagnosticsCopy.batteryUnavailable)
                }
            }

            Section(DiagnosticsCopy.diagnosticTools) {
                destinationRow(
                    .connection,
                    subtitle: DiagnosticsCopy.connectionDetail,
                    image: "antenna.radiowaves.left.and.right",
                    tint: DesignColor.informational
                )
                destinationRow(
                    .telemetry,
                    subtitle: DiagnosticsCopy.telemetryDetail,
                    image: "waveform.path.ecg",
                    tint: DesignColor.warning
                )
                destinationRow(
                    .status,
                    subtitle: DiagnosticsCopy.statusDetail,
                    image: "checklist",
                    tint: DesignColor.positive
                )
                destinationRow(
                    .events,
                    subtitle: DiagnosticsCopy.eventsDetail,
                    image: "list.bullet.rectangle",
                    tint: .purple
                )
                destinationRow(
                    .bleLogs,
                    subtitle: DiagnosticsCopy.bleLogsDetail,
                    image: "dot.radiowaves.left.and.right",
                    tint: .indigo
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(DiagnosticsCopy.changeBike, role: .destructive, action: onChangeBike)
            }
        }
    }

    private func destinationRow(
        _ destination: BikeDiagnosticsDestination,
        subtitle: String,
        image: String,
        tint: Color
    ) -> some View {
        DiagnosticsDestinationRow(
            title: destination.title,
            subtitle: subtitle,
            systemImage: image,
            tint: tint,
            action: { onNavigate(destination) }
        )
    }

    private var statusImage: String {
        switch state.connection.emphasis {
        case .success: "checkmark.circle.fill"
        case .progress: "arrow.triangle.2.circlepath"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .neutral: "circle.dotted"
        }
    }

    private var statusColor: Color {
        switch state.connection.emphasis {
        case .success: DesignColor.positive
        case .progress: DesignColor.informational
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        case .neutral: .secondary
        }
    }
}
