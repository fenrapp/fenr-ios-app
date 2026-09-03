import DesignSystem
import SwiftUI
import UIKit

struct DiagnosticsEventsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: BikeDiagnosticsViewState
    let logTextProvider: () -> String
    let onClear: () -> Void

    @State private var confirmsClear = false

    var body: some View {
        List {
            Section {
                ListActionButton(
                    title: DiagnosticsCopy.completeLogCopy,
                    systemImage: "doc.on.doc",
                    tint: DesignColor.informational,
                    isEnabled: state.hasDebugLog,
                    action: copyLog
                )

                ListActionShareLink(
                    item: logTextProvider(),
                    title: DiagnosticsCopy.completeLogExport,
                    systemImage: "square.and.arrow.up",
                    tint: .indigo,
                    isEnabled: state.hasDebugLog
                )

                ListActionButton(
                    title: DiagnosticsCopy.clearEvents,
                    systemImage: "trash",
                    isEnabled: !state.debugEvents.isEmpty,
                    isDestructive: true,
                    action: { confirmsClear = true }
                )
            } footer: {
                Text(verbatim: DiagnosticsCopy.eventsExportFooter)
            }

            Section(DiagnosticsCopy.recentEvents) {
                if state.debugEvents.isEmpty {
                    Text(verbatim: DiagnosticsCopy.noEvents)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.debugEvents) { event in
                        VStack(alignment: .leading, spacing: Constants.eventSpacing) {
                            eventHeader(event)
                            Text(event.detail)
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, Constants.eventPadding)
                    }
                }
            }
        }
        .confirmationDialog(
            DiagnosticsCopy.clearEventsPrompt,
            isPresented: $confirmsClear,
            titleVisibility: .visible
        ) {
            Button(DiagnosticsCopy.clearEvents, role: .destructive, action: onClear)
            Button(DiagnosticsCopy.cancel, role: .cancel) {}
        } message: {
            Text(verbatim: DiagnosticsCopy.clearEventsMessage)
        }
    }

    private func copyLog() {
        UIPasteboard.general.string = logTextProvider()
    }

    @ViewBuilder
    private func eventHeader(_ event: DebugEventViewData) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Constants.eventSpacing) {
                eventTitle(event)
                eventTime(event)
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                eventTitle(event)
                Spacer()
                eventTime(event)
            }
        }
    }

    private func eventTitle(_ event: DebugEventViewData) -> some View {
        Text(event.title)
            .font(.headline)
    }

    private func eventTime(_ event: DebugEventViewData) -> some View {
        Text(event.time)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private enum Constants {
        static let eventSpacing: CGFloat = 6
        static let eventPadding: CGFloat = 4
    }
}
