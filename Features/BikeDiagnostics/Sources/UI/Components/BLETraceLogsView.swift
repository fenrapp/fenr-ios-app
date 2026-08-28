import DesignSystem
import SwiftUI

struct BLETraceLogsView: View {
    let sessions: [BLETraceSessionViewData]
    let error: String?
    let onExport: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onDeleteAll: () -> Void

    @State private var deleteRequest: DeleteRequest?

    var body: some View {
        SurfacePanel(title: "BLE Capture Logs") {
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if sessions.isEmpty {
                Text("No BLE capture logs yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: Constants.rowSpacing) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                        if session.id != sessions.last?.id {
                            Divider()
                        }
                    }
                }
                Button(role: .destructive) {
                    deleteRequest = .all
                } label: {
                    Label("Delete All Logs", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .alert(item: $deleteRequest) { request in
            switch request {
            case .session(let id):
                Alert(
                    title: Text("Delete BLE Log?"),
                    message: Text("This capture cannot be recovered."),
                    primaryButton: .destructive(Text("Delete")) { onDelete(id) },
                    secondaryButton: .cancel()
                )
            case .all:
                Alert(
                    title: Text("Delete All BLE Logs?"),
                    message: Text("Active recording is kept. Completed captures cannot be recovered."),
                    primaryButton: .destructive(Text("Delete All"), action: onDeleteAll),
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func sessionRow(_ session: BLETraceSessionViewData) -> some View {
        VStack(alignment: .leading, spacing: Constants.contentSpacing) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Constants.textSpacing) {
                    Text(session.date)
                        .font(.caption.weight(.semibold))
                    Text("\(session.status) | \(session.duration) | \(session.size)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Constants.minimumSpacerLength)
                if session.isActive {
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Recording")
                }
            }
            HStack(spacing: Constants.buttonSpacing) {
                Button {
                    onExport(session.id)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    deleteRequest = .session(session.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!session.canDelete)
            }
            .font(.caption.weight(.semibold))
        }
    }

    private enum DeleteRequest: Identifiable {
        case session(UUID)
        case all

        var id: String {
            switch self {
            case .session(let id): "session-\(id.uuidString)"
            case .all: "all"
            }
        }
    }

    private enum Constants {
        static let rowSpacing = DesignSpace.small
        static let contentSpacing = DesignSpace.extraSmall
        static let textSpacing = DesignSpace.extraExtraSmall
        static let buttonSpacing = DesignSpace.extraSmall
        static let minimumSpacerLength = DesignSpace.extraSmall
    }
}
