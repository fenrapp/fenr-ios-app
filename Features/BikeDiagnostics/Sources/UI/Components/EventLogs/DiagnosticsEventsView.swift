import SwiftUI
import UIKit

struct DiagnosticsEventsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: BikeDiagnosticsViewState
    let logTextProvider: () -> String
    let onClear: () -> Void

    @State private var confirmsClear = false
    @State private var feedbackToken = 0

    var body: some View {
        List {
            Section {
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
            } header: {
                Text(verbatim: DiagnosticsCopy.recentEvents)
            } footer: {
                Text(verbatim: DiagnosticsCopy.eventsExportFooter)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: copyLog) {
                        Label(DiagnosticsCopy.completeLogCopy, systemImage: "doc.on.doc")
                    }
                    .disabled(!state.hasDebugLog)

                    ShareLink(item: logTextProvider()) {
                        Label(DiagnosticsCopy.completeLogExport, systemImage: "square.and.arrow.up")
                    }
                    .disabled(!state.hasDebugLog)

                    Divider()

                    Button(role: .destructive) {
                        confirmsClear = true
                    } label: {
                        Label(DiagnosticsCopy.clearEvents, systemImage: "trash")
                    }
                    .disabled(state.debugEvents.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: Constants.toolbarTarget, minHeight: Constants.toolbarTarget)
                }
                .accessibilityLabel(DiagnosticsCopy.actions)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackToken)
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
        feedbackToken += 1
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
        static let toolbarTarget: CGFloat = 44
    }
}
