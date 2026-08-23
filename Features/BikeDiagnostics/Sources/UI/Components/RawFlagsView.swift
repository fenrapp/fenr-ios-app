import DesignSystem
import SwiftUI

struct RawFlagsView: View {
    let flags: [BikeDiagnosticsMetricViewData]

    var body: some View {
        SurfacePanel(title: "Raw Flags") {
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                ForEach(flags) { flag in
                    HStack(alignment: .firstTextBaseline, spacing: Constants.rowSpacing) {
                        Text(flag.title)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(Constants.lineLimit)
                        Spacer(minLength: Constants.minimumSpacerLength)
                        Text(flag.value)
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                            .lineLimit(Constants.lineLimit)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private enum Constants {
        static let contentSpacing = DesignSpace.extraSmall
        static let rowSpacing = DesignSpace.extraSmall
        static let minimumSpacerLength = DesignSpace.extraSmall
        static let lineLimit = 1
    }
}

#Preview("Raw Flags") {
    RawFlagsView(flags: [
        .init(id: "misc", title: "miscBits", value: "0x000C"),
        .init(id: "info", title: "infoBits", value: "0x0019")
    ])
    .padding()
}
