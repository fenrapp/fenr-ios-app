import DesignSystem
import SwiftUI

struct DiagnosticsBLETraceDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let session: BLETraceSessionViewData
    let onExport: () -> Void
    let onDelete: () -> Void

    @State private var confirmsDelete = false

    var body: some View {
        List {
            Section {
                LabeledContent(DiagnosticsCopy.started, value: session.date)
                LabeledContent(DiagnosticsCopy.status, value: session.status)
                LabeledContent(DiagnosticsCopy.duration, value: session.duration)
                LabeledContent(DiagnosticsCopy.size, value: session.size)
                LabeledContent(DiagnosticsCopy.eventCount, value: session.eventCount)
            }
            .textSelection(.enabled)

            Section(DiagnosticsCopy.actions) {
                ListActionButton(
                    title: DiagnosticsCopy.copyMetadata,
                    systemImage: "doc.on.doc",
                    tint: DesignColor.informational
                ) {
                    DiagnosticsBLETraceMetadata.copy(session)
                }
                ListActionButton(
                    title: DiagnosticsCopy.export,
                    systemImage: "square.and.arrow.up",
                    tint: .indigo,
                    action: onExport
                )
                .accessibilityIdentifier("diagnostics.bleLogs.export")
                if session.canDelete {
                    ListActionButton(
                        title: DiagnosticsCopy.delete,
                        systemImage: "trash",
                        isDestructive: true
                    ) {
                        confirmsDelete = true
                    }
                    .accessibilityIdentifier("diagnostics.bleLogs.delete")
                }
            }
        }
        .navigationTitle(DiagnosticsCopy.bleLog)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            DiagnosticsCopy.deleteSessionPrompt,
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button(DiagnosticsCopy.delete, role: .destructive) {
                onDelete()
                dismiss()
            }
            Button(DiagnosticsCopy.cancel, role: .cancel) {}
        } message: {
            Text(verbatim: DiagnosticsCopy.deleteSessionMessage)
        }
    }
}
