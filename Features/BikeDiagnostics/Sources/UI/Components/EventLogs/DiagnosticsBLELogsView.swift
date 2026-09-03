import DesignSystem
import SwiftUI
import UIKit

struct DiagnosticsBLELogsView: View {
    let state: BikeDiagnosticsViewState
    let onExport: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onDeleteAll: () -> Void

    @State private var deleteRequest: DeleteRequest?

    var body: some View {
        List {
            if let error = state.bleTraceError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                if state.bleTraceSessions.isEmpty {
                    Text(verbatim: DiagnosticsCopy.noSessions)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.bleTraceSessions) { session in
                        sessionRow(session)
                    }
                }
            } footer: {
                Text(verbatim: DiagnosticsCopy.traceFooter)
            }

            if !state.bleTraceSessions.isEmpty {
                Section {
                    ListActionButton(
                        title: DiagnosticsCopy.deleteAllSessions,
                        systemImage: "trash",
                        isDestructive: true
                    ) {
                        deleteRequest = .all
                    }
                }
            }
        }
        .confirmationDialog(
            deleteRequest?.title ?? DiagnosticsCopy.deleteLogPrompt,
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button(DiagnosticsCopy.delete, role: .destructive, action: confirmDelete)
            Button(DiagnosticsCopy.cancel, role: .cancel) { deleteRequest = nil }
        } message: {
            Text(verbatim: deleteRequest?.message ?? DiagnosticsCopy.deleteFallbackMessage)
        }
    }

    private func sessionRow(_ session: BLETraceSessionViewData) -> some View {
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            LabeledContent(DiagnosticsCopy.started, value: session.date)
            LabeledContent(DiagnosticsCopy.status, value: session.status)
            LabeledContent(DiagnosticsCopy.duration, value: session.duration)
            LabeledContent(DiagnosticsCopy.size, value: session.size)
            VStack(alignment: .leading, spacing: .zero) {
                ListActionButton(
                    title: DiagnosticsCopy.copyMetadata,
                    systemImage: "doc.on.doc",
                    tint: DesignColor.informational
                ) {
                    copyMetadata(session)
                }
                ListActionButton(
                    title: DiagnosticsCopy.export,
                    systemImage: "square.and.arrow.up",
                    tint: .indigo
                ) {
                    onExport(session.id)
                }
                ListActionButton(
                    title: DiagnosticsCopy.delete,
                    systemImage: "trash",
                    isEnabled: session.canDelete,
                    isDestructive: true
                ) {
                    deleteRequest = .session(session.id)
                }
            }
        }
        .textSelection(.enabled)
        .padding(.vertical, Constants.rowPadding)
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { deleteRequest != nil },
            set: { if !$0 { deleteRequest = nil } }
        )
    }

    private func confirmDelete() {
        guard let request = deleteRequest else { return }
        switch request {
        case .session(let id): onDelete(id)
        case .all: onDeleteAll()
        }
        deleteRequest = nil
    }

    private func copyMetadata(_ session: BLETraceSessionViewData) {
        UIPasteboard.general.string = [
            "\(DiagnosticsCopy.started): \(session.date)",
            "\(DiagnosticsCopy.status): \(session.status)",
            "\(DiagnosticsCopy.duration): \(session.duration)",
            "\(DiagnosticsCopy.size): \(session.size)"
        ].joined(separator: "\n")
    }

    private enum DeleteRequest {
        case session(UUID)
        case all

        var title: String {
            switch self {
            case .session: DiagnosticsCopy.deleteSessionPrompt
            case .all: DiagnosticsCopy.deleteAllSessionsPrompt
            }
        }

        var message: String {
            switch self {
            case .session: DiagnosticsCopy.deleteSessionMessage
            case .all: DiagnosticsCopy.deleteAllSessionsMessage
            }
        }
    }

    private enum Constants {
        static let rowSpacing: CGFloat = 8
        static let rowPadding: CGFloat = 4
    }
}
