import DesignSystem
import SwiftUI

struct DiagnosticsConnectionView: View {
    let state: BikeDiagnosticsViewState
    let onReconnect: () -> Void
    let onRetry: () -> Void
    let onDisconnect: () -> Void
    let onChangeBike: () -> Void

    var body: some View {
        List {
            Section(DiagnosticsCopy.connectionState) {
                LabeledContent(DiagnosticsCopy.status, value: state.connection.status)
                Text(state.connection.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                LabeledContent(DiagnosticsCopy.signal, value: state.connection.rssi)
            }

            Section(DiagnosticsCopy.readOnlyIdentity) {
                selectableRow(
                    DiagnosticsCopy.configuredIdentity,
                    value: state.connection.configuredVIN
                )
                selectableRow(
                    DiagnosticsCopy.peripheral,
                    value: state.connection.peripheralName
                )
                selectableRow(
                    DiagnosticsCopy.peripheralUUID,
                    value: state.connection.peripheralIdentifier
                )
            }

            Section(DiagnosticsCopy.actions) {
                ListActionButton(
                    title: DiagnosticsCopy.reconnect,
                    systemImage: "arrow.clockwise",
                    tint: DesignColor.informational,
                    isEnabled: state.isReconnectEnabled,
                    action: onReconnect
                )
                ListActionButton(
                    title: DiagnosticsCopy.retryHandshake,
                    systemImage: "key.fill",
                    tint: DesignColor.warning,
                    isEnabled: state.isPairRetryEnabled,
                    action: onRetry
                )
                ListActionButton(
                    title: DiagnosticsCopy.disconnect,
                    systemImage: "xmark.circle",
                    isEnabled: state.isDisconnectEnabled,
                    isDestructive: true,
                    action: onDisconnect
                )
                ListActionButton(
                    title: DiagnosticsCopy.changeBike,
                    systemImage: "motorcycle",
                    tint: DesignColor.warning,
                    isEnabled: true,
                    isDestructive: true,
                    action: onChangeBike
                )
            }
        }
    }

    private func selectableRow(_ title: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.callout.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        } label: {
            Text(title)
        }
    }

}
