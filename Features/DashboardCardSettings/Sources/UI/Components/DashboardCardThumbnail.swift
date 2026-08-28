import DesignSystem
import SwiftUI

struct DashboardCardThumbnail: View {
    let state: DashboardCardThumbnailViewData

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignRadius.small, style: .continuous)
                .fill(DesignColor.groupedSurface)
            RoundedRectangle(cornerRadius: DesignRadius.small, style: .continuous)
                .stroke(DesignColor.border, lineWidth: Constants.borderWidth)
            content
                .foregroundStyle(accentColor)
                .padding(Constants.contentPadding)
        }
        .frame(width: Constants.width, height: Constants.height)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch state.style {
        case .gauge:
            ZStack {
                Circle()
                    .trim(from: Constants.gaugeStart, to: Constants.gaugeEnd)
                    .stroke(style: .init(lineWidth: Constants.gaugeWidth, lineCap: .round))
                    .rotationEffect(.degrees(Constants.gaugeRotation))
                Image(systemName: state.systemImage)
                    .font(.caption2.weight(.semibold))
            }
        case .charging:
            HStack(spacing: Constants.smallSpacing) {
                Image(systemName: "battery.75percent")
                Image(systemName: state.systemImage)
            }
            .font(.caption.weight(.semibold))
        case .metrics:
            VStack(spacing: Constants.smallSpacing) {
                Image(systemName: state.systemImage)
                    .font(.caption.weight(.semibold))
                HStack(spacing: Constants.smallSpacing) {
                    metricBar(width: Constants.shortBarWidth)
                    metricBar(width: Constants.longBarWidth)
                }
            }
        case .chart:
            HStack(alignment: .bottom, spacing: Constants.chartSpacing) {
                ForEach(Constants.chartHeights.indices, id: \.self) { index in
                    Capsule().frame(width: Constants.chartBarWidth, height: Constants.chartHeights[index])
                }
            }
        case .battery:
            HStack(spacing: Constants.smallSpacing) {
                Image(systemName: state.systemImage)
                VStack(alignment: .leading, spacing: Constants.smallSpacing) {
                    metricBar(width: Constants.longBarWidth)
                    metricBar(width: Constants.shortBarWidth)
                }
            }
            .font(.caption.weight(.semibold))
        case .grid:
            Grid(horizontalSpacing: Constants.gridSpacing, verticalSpacing: Constants.gridSpacing) {
                GridRow { gridCell(); gridCell(); gridCell() }
                GridRow { gridCell(); gridCell(); gridCell() }
            }
        case .attitude:
            ZStack {
                Circle().stroke(lineWidth: Constants.attitudeLineWidth)
                Capsule()
                    .frame(width: Constants.attitudeWidth, height: Constants.attitudeLineWidth)
                    .rotationEffect(.degrees(Constants.attitudeRotation))
                Image(systemName: state.systemImage)
                    .font(.system(size: Constants.attitudeSymbolSize, weight: .bold))
            }
        case .compass:
            ZStack {
                Circle().stroke(lineWidth: Constants.attitudeLineWidth)
                Image(systemName: state.systemImage)
                    .font(.caption.weight(.bold))
            }
        }
    }

    private func metricBar(width: CGFloat) -> some View {
        Capsule().frame(width: width, height: Constants.metricBarHeight)
    }

    private func gridCell() -> some View {
        RoundedRectangle(cornerRadius: Constants.gridRadius)
            .frame(width: Constants.gridCellSize, height: Constants.gridCellSize)
    }

    private var accentColor: Color {
        switch state.accent {
        case .accent: DesignColor.accent
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        case .informational: DesignColor.informational
        }
    }

    private enum Constants {
        static let width: CGFloat = 62
        static let height: CGFloat = 44
        static let borderWidth: CGFloat = 1
        static let contentPadding: CGFloat = 7
        static let smallSpacing: CGFloat = 3
        static let gaugeStart: CGFloat = 0.08
        static let gaugeEnd: CGFloat = 0.92
        static let gaugeWidth: CGFloat = 3
        static let gaugeRotation: Double = 104
        static let metricBarHeight: CGFloat = 3
        static let shortBarWidth: CGFloat = 10
        static let longBarWidth: CGFloat = 17
        static let chartSpacing: CGFloat = 3
        static let chartBarWidth: CGFloat = 4
        static let chartHeights: [CGFloat] = [8, 15, 11, 22, 17]
        static let gridSpacing: CGFloat = 3
        static let gridRadius: CGFloat = 1.5
        static let gridCellSize: CGFloat = 7
        static let attitudeLineWidth: CGFloat = 2
        static let attitudeWidth: CGFloat = 27
        static let attitudeRotation: Double = -16
        static let attitudeSymbolSize: CGFloat = 8
    }
}
