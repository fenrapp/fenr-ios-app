import DesignSystem
import SwiftUI

struct DiagnosticsBLELogsView: View {
    let state: BikeDiagnosticsViewState
    let onToggleCapture: () -> Void
    let onExport: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onDeleteAll: () -> Void

    @State private var deleteRequest: DeleteRequest?
    @State private var feedbackToken = 0

    var body: some View {
        List {
            if let error = state.bleTraceError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignColor.critical)
                }
            }

            if let activeSession {
                Section(DiagnosticsCopy.recordingNow) {
                    sessionLink(activeSession)
                }
            }

            if previousSessions.isEmpty {
                if activeSession == nil {
                    Section {
                        ContentUnavailableView(
                            DiagnosticsCopy.noSessions,
                            systemImage: "waveform.badge.magnifyingglass"
                        )
                    }
                }
            } else {
                Section {
                    ForEach(previousSessions) { session in
                        sessionLink(session)
                    }
                } header: {
                    Text(verbatim: DiagnosticsCopy.previousCaptures)
                } footer: {
                    Text(verbatim: DiagnosticsCopy.traceFooter)
                }

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
        .toolbar { captureToolbar }
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackToken)
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

    @ToolbarContentBuilder
    private var captureToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if state.isBLETraceCaptureControlInProgress {
                ProgressView()
                    .controlSize(.small)
                    .frame(minWidth: Constants.toolbarTarget, minHeight: Constants.toolbarTarget)
                    .accessibilityLabel(captureActionTitle)
            } else {
                Button {
                    feedbackToken += 1
                    onToggleCapture()
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(DesignColor.critical)
                        .frame(minWidth: Constants.toolbarTarget, minHeight: Constants.toolbarTarget)
                }
                .disabled(!captureControlIsEnabled)
                .accessibilityLabel(captureActionTitle)
            }
        }
    }

    private func sessionLink(_ session: BLETraceSessionViewData) -> some View {
        NavigationLink {
            DiagnosticsBLETraceDetailView(
                session: session,
                onExport: { onExport(session.id) },
                onDelete: { onDelete(session.id) }
            )
        } label: {
            DiagnosticsBLETraceRow(session: session)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                feedbackToken += 1
                onExport(session.id)
            } label: {
                Label(DiagnosticsCopy.export, systemImage: "square.and.arrow.up")
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if session.canDelete {
                Button(role: .destructive) {
                    deleteRequest = .session(session.id)
                } label: {
                    Label(DiagnosticsCopy.delete, systemImage: "trash")
                }
            }
        }
        .contextMenu {
            Button {
                feedbackToken += 1
                DiagnosticsBLETraceMetadata.copy(session)
            } label: {
                Label(DiagnosticsCopy.copyMetadata, systemImage: "doc.on.doc")
            }
            Button {
                feedbackToken += 1
                onExport(session.id)
            } label: {
                Label(DiagnosticsCopy.export, systemImage: "square.and.arrow.up")
            }
            if session.canDelete {
                Divider()
                Button(role: .destructive) {
                    deleteRequest = .session(session.id)
                } label: {
                    Label(DiagnosticsCopy.delete, systemImage: "trash")
                }
            }
        }
    }

    private var activeSession: BLETraceSessionViewData? {
        state.bleTraceSessions.first(where: \.isActive)
    }

    private var previousSessions: [BLETraceSessionViewData] {
        state.bleTraceSessions.filter { !$0.isActive }
    }

    private var isRecording: Bool {
        activeSession != nil
    }

    private var captureControlIsEnabled: Bool {
        isRecording || state.isDisconnectEnabled
    }

    private var captureActionTitle: String {
        isRecording ? DiagnosticsCopy.stopBLELog : DiagnosticsCopy.startNewBLELog
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
        static let toolbarTarget: CGFloat = 44
    }
}
