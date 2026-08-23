import DesignSystem
import SwiftUI
import UIKit

struct DebugEventsView: View {
    let events: [DebugEventViewData]
    let hasLog: Bool
    let logTextProvider: () -> String

    var body: some View {
        SurfacePanel(title: "Debug Events") {
            copyButton
            if events.isEmpty {
                Text("No events yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: Constants.eventSpacing) {
                            HStack(spacing: Constants.titleSpacing) {
                                Text(event.time)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: Constants.timeWidth, alignment: .leading)
                                Text(event.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(Constants.titleLineLimit)
                                Spacer(minLength: Constants.minimumSpacerLength)
                            }
                            Text(event.detail)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(Constants.detailLineLimit)
                                .minimumScaleFactor(Constants.minimumScaleFactor)
                                .textSelection(.enabled)
                        }
                        if event.id != events.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var copyButton: some View {
        Button(action: copyLog) {
            Label("Copy log", systemImage: "doc.on.doc")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .disabled(!hasLog)
        .accessibilityLabel("Copy debug log")
    }

    private func copyLog() {
        UIPasteboard.general.string = logTextProvider()
    }

    private enum Constants {
        static let contentSpacing = DesignSpace.small
        static let eventSpacing = DesignSpace.extraExtraSmall
        static let titleSpacing = DesignSpace.extraSmall
        static let timeWidth: CGFloat = 62
        static let minimumSpacerLength = DesignSpace.extraSmall
        static let titleLineLimit = 1
        static let detailLineLimit = 3
        static let minimumScaleFactor = 0.8
    }
}

#Preview("Debug") {
    DebugEventsView(
        events: [
            .init(
                id: UUID(),
                time: "10:31:44",
                title: "Notification",
                detail: "00006004-5374-6172-4B20-467574757265 4b 5B 00 63 00"
            ),
            .init(id: UUID(), time: "10:31:42", title: "Connection", detail: "Subscribed")
        ],
        hasLog: true,
        logTextProvider: {
            "10:31:44 | Notification | 00006004-5374-6172-4B20-467574757265 4b 5B 00 63 00"
        }
    )
    .padding()
}
