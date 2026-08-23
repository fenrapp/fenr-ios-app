import DesignSystem
import SwiftUI

struct ConnectionPanelView: View {
    let model: ConnectionPanelViewData

    var body: some View {
        SurfacePanel(title: "Connection") {
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                HStack(alignment: .center, spacing: Constants.statusSpacing) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: Constants.statusDotSize, height: Constants.statusDotSize)
                    Text(model.status)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .lineLimit(Constants.statusLineLimit)
                        .minimumScaleFactor(Constants.minimumScaleFactor)
                }

                Text(model.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(Constants.detailLineLimit)

                HStack(spacing: Constants.metadataSpacing) {
                    Label(model.rssi, systemImage: "dot.radiowaves.left.and.right")
                    Spacer(minLength: Constants.minimumSpacerLength)
                }
                .font(.callout)

                Text(model.peripheral)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(Constants.peripheralLineLimit)
                    .minimumScaleFactor(Constants.minimumScaleFactor)
                    .textSelection(.enabled)
            }
        }
    }

    private var statusColor: Color {
        switch model.status.lowercased() {
        case "receiving telemetry", "connected":
            return DesignColor.positive
        case "scanning", "connecting", "discovering", "waiting for data":
            return DesignColor.warning
        case "failed", "error", "unauthorized":
            return DesignColor.critical
        default:
            return .secondary
        }
    }

    private enum Constants {
        static let contentSpacing = DesignSpace.extraSmall
        static let statusSpacing = DesignSpace.extraSmall
        static let metadataSpacing = DesignSpace.extraSmall
        static let statusDotSize: CGFloat = 10
        static let minimumSpacerLength = DesignSpace.extraSmall
        static let statusLineLimit = 1
        static let detailLineLimit = 2
        static let peripheralLineLimit = 2
        static let minimumScaleFactor = 0.75
    }
}

#Preview("Connection") {
    ConnectionPanelView(model: .init(
        status: "Receiving telemetry",
        detail: "Secure telemetry active",
        rssi: "-61 dBm",
        peripheral: "FENRTEST000000001\n9B42F2A0-AAAA-BBBB-CCCC-123456789ABC"
    ))
        .padding()
}
