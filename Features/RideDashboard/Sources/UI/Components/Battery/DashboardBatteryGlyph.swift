import SwiftUI

struct DashboardBatteryGlyph: View {
    let fillFraction: CGFloat
    let fillColor: Color
    let compact: Bool

    var body: some View {
        GeometryReader { proxy in
            let bodyWidth = proxy.size.width - terminalWidth - terminalSpacing
            let inset = outlineWidth
            let fillWidth = max(.zero, (bodyWidth - (inset * 2)) * fillFraction)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary, lineWidth: outlineWidth)
                    .frame(width: bodyWidth)

                RoundedRectangle(cornerRadius: fillCornerRadius, style: .continuous)
                    .fill(fillColor)
                    .frame(width: fillWidth, height: proxy.size.height - (inset * 2))
                    .padding(.leading, inset)

                Capsule()
                    .fill(Color.primary)
                    .frame(width: terminalWidth, height: proxy.size.height * terminalHeightRatio)
                    .offset(x: bodyWidth + terminalSpacing)
            }
        }
        .frame(
            width: compact ? Constants.compactWidth : Constants.width,
            height: compact ? Constants.compactHeight : Constants.height
        )
    }

    private var outlineWidth: CGFloat { compact ? Constants.compactOutlineWidth : Constants.outlineWidth }
    private var cornerRadius: CGFloat { compact ? Constants.compactCornerRadius : Constants.cornerRadius }
    private var fillCornerRadius: CGFloat { compact ? Constants.compactFillCornerRadius : Constants.fillCornerRadius }
    private var terminalWidth: CGFloat { compact ? Constants.compactTerminalWidth : Constants.terminalWidth }
    private var terminalSpacing: CGFloat { compact ? Constants.compactTerminalSpacing : Constants.terminalSpacing }
    private var terminalHeightRatio: CGFloat { Constants.terminalHeightRatio }

    private enum Constants {
        static let width: CGFloat = 40
        static let height: CGFloat = 20
        static let compactWidth: CGFloat = 32
        static let compactHeight: CGFloat = 16
        static let outlineWidth: CGFloat = 2
        static let compactOutlineWidth: CGFloat = 1.5
        static let cornerRadius: CGFloat = 4
        static let compactCornerRadius: CGFloat = 3
        static let fillCornerRadius: CGFloat = 2
        static let compactFillCornerRadius: CGFloat = 1.5
        static let terminalWidth: CGFloat = 4
        static let compactTerminalWidth: CGFloat = 3
        static let terminalSpacing: CGFloat = 2
        static let compactTerminalSpacing: CGFloat = 1.5
        static let terminalHeightRatio: CGFloat = 0.45
    }
}
