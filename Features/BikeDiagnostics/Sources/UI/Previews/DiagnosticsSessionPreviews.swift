import Foundation
import SwiftUI

#Preview("Connection - disconnected") {
    NavigationStack {
        DiagnosticsConnectionView(
            state: .init(
                connection: .init(
                    status: "Disconnected", detail: "No active connection", rssi: "--",
                    configuredVIN: "FENRTEST000000001", emphasis: .warning
                ),
                isReconnectEnabled: true, isPairRetryEnabled: true
            ),
            onReconnect: {}, onRetry: {}, onDisconnect: {}
        )
    }
}

#Preview("Connection - connected - large text") {
    NavigationStack {
        DiagnosticsConnectionView(
            state: .init(
                connection: .init(
                    status: "Receiving telemetry", detail: "Secure telemetry is active", rssi: "-48 dBm",
                    configuredVIN: "FENRTEST000000001", peripheralName: "Preview motorcycle",
                    peripheralIdentifier: "00000000-0000-0000-0000-000000000001", emphasis: .success
                ),
                isDisconnectEnabled: true
            ),
            onReconnect: {}, onRetry: {}, onDisconnect: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("BLE captures - recording and history") {
    NavigationStack {
        DiagnosticsBLELogsView(
            state: .init(
                bleTraceSessions: [SessionPreviewData.recording, SessionPreviewData.completed],
                isBLETraceCaptureAvailable: true
            ),
            onToggleCapture: {}, onExport: { _ in }, onDelete: { _ in }, onDeleteAll: {}
        )
    }
}

#Preview("BLE captures - empty and error") {
    NavigationStack {
        DiagnosticsBLELogsView(
            state: .init(bleTraceError: "Unable to start a new capture. Try again."),
            onToggleCapture: {}, onExport: { _ in }, onDelete: { _ in }, onDeleteAll: {}
        )
    }
}

#Preview("BLE capture detail") {
    NavigationStack {
        DiagnosticsBLETraceDetailView(session: SessionPreviewData.completed, onExport: {}, onDelete: {})
    }
}

#Preview("Diagnostics events - populated - large text") {
    NavigationStack {
        DiagnosticsEventsView(
            state: .init(
                debugEvents: [
                    .init(id: UUID(), time: "10:42:15", title: "Connected", detail: "Synthetic connection event"),
                    .init(id: UUID(), time: "10:42:14", title: "Scanning", detail: "Searching for the preview bike")
                ],
                hasDebugLog: true
            ),
            logTextProvider: { "Synthetic preview log" }, onClear: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Diagnostics events - empty") {
    NavigationStack {
        DiagnosticsEventsView(state: .init(), logTextProvider: { "" }, onClear: {})
    }
}

private enum SessionPreviewData {
    static let recording = BLETraceSessionViewData(
        id: UUID(), date: "Today, 10:42", duration: "2 min", size: "84 KB", eventCount: "128",
        status: "Recording", statusKind: .recording, isActive: true, canDelete: false
    )
    static let completed = BLETraceSessionViewData(
        id: UUID(), date: "Yesterday, 18:30", duration: "12 min", size: "640 KB", eventCount: "1,024",
        status: "Complete", statusKind: .complete, isActive: false, canDelete: true
    )
}
