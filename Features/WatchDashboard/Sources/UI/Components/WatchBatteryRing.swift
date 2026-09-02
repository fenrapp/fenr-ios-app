import DesignSystem
import SwiftUI

struct WatchBatteryRing: View {
    let percentage: Int?
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth = max(
                Constants.minimumLineWidth,
                min(size * Constants.lineWidthMultiplier, Constants.maximumLineWidth)
            )

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth, value: progress)

                HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
                    Text(verbatim: percentage.map(String.init) ?? "--")
                        .font(
                            .system(
                                size: size * Constants.valueFontMultiplier,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .contentTransition(.numericText())
                    if percentage != nil {
                        Text(verbatim: "%")
                            .font(
                                .system(
                                    size: size * Constants.percentFontMultiplier,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                    }
                }
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(
            Text(
                percentage.map {
                    .watchDashboardAccessibilityBatteryPercent(percentage: $0)
                } ?? .watchDashboardAccessibilityBatteryUnknown
            )
        )
    }

    private var progress: Double {
        min(max(Double(percentage ?? 0), .zero), Constants.maximumPercentage)
            / Constants.maximumPercentage
    }

    private enum Constants {
        static let minimumLineWidth: CGFloat = 8
        static let maximumLineWidth: CGFloat = 16
        static let lineWidthMultiplier = 0.1
        static let valueFontMultiplier = 0.4
        static let percentFontMultiplier = 0.16
        static let maximumPercentage = 100.0
    }
}

#if DEBUG
#Preview {
    WatchBatteryRing(percentage: 72, tint: .green)
        .frame(width: 120, height: 120)
        .padding()
}
#endif
