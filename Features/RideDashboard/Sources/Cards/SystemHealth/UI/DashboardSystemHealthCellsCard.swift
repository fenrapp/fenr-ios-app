import DesignSystem
import SwiftUI

struct DashboardSystemHealthCellsCard: View {
    let state: DashboardSystemHealthViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(spacing: Constants.spacing) {
                DashboardSystemHealthHeader(title: "CELL HEALTH", state: state)
                summary
                if state.cells.isEmpty {
                    emptyState
                } else {
                    distribution
                    extremes
                    balancingStatus
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(state.cellDeltaText)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("CELL DELTA")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DesignColor.secondaryText)
            }
            Spacer()
            Text(issueSummaryText)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(issueColor)
        }
    }

    private var distribution: some View {
        VStack(spacing: DesignSpace.small) {
            HStack {
                Text("PACK DISTRIBUTION")
                Spacer()
                Text("\(state.cells.count) CELLS")
                    .monospacedDigit()
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(DesignColor.secondaryText)

            CellHealthDistributionBar(
                normalCount: normalCellCount,
                attentionCount: state.attentionCellCount,
                criticalCount: state.criticalCellCount
            )

            HStack(spacing: DesignSpace.extraSmall) {
                distributionMetric("NORMAL", value: normalCellCount, color: DesignColor.positive)
                distributionMetric("CHECK", value: state.attentionCellCount, color: DesignColor.warning)
                distributionMetric("CRITICAL", value: state.criticalCellCount, color: DesignColor.critical)
            }
        }
        .padding(DesignSpace.small)
        .background(DesignColor.elevatedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.small))
    }

    private var extremes: some View {
        HStack(spacing: DesignSpace.small) {
            extremeMetric(title: "LOWEST", value: state.minimumCellText, systemImage: "arrow.down")
            extremeMetric(title: "HIGHEST", value: state.maximumCellText, systemImage: "arrow.up")
        }
    }

    @ViewBuilder
    private var balancingStatus: some View {
        if state.balancingCellCount > .zero {
            Label("\(state.balancingCellCount) BALANCING", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.informational)
                .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSpace.small) {
            ProgressView()
                .tint(DesignColor.informational)
            Text(state.statusDetail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var normalCellCount: Int {
        max(.zero, state.cells.count - state.attentionCellCount - state.criticalCellCount)
    }

    private var issueSummaryText: String {
        if state.criticalCellCount > .zero { return "\(state.criticalCellCount) CRITICAL" }
        if state.attentionCellCount > .zero { return "\(state.attentionCellCount) TO CHECK" }
        return "UNIFORM PACK"
    }

    private var issueColor: Color {
        if state.criticalCellCount > .zero { return DesignColor.critical }
        if state.attentionCellCount > .zero { return DesignColor.warning }
        return DesignColor.positive
    }

    private func distributionMetric(_ title: String, value: Int, color: Color) -> some View {
        VStack(spacing: DesignSpace.extraExtraSmall) {
            Text(value.formatted())
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func extremeMetric(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Constants.minimumTextScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSpace.small)
        .background(DesignColor.elevatedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.small))
    }

    private var accessibilityText: String {
        [
            "Cell health \(state.statusText)",
            "cell delta \(state.cellDeltaText)",
            "\(normalCellCount) normal cells",
            "\(state.attentionCellCount) cells to check",
            "\(state.criticalCellCount) critical cells",
            "lowest \(state.minimumCellText)",
            "highest \(state.maximumCellText)",
            "\(state.balancingCellCount) balancing"
        ].joined(separator: ", ")
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let minimumTextScale = 0.75
    }
}

private struct CellHealthDistributionBar: View {
    let normalCount: Int
    let attentionCount: Int
    let criticalCount: Int

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
                - CGFloat(max(.zero, populatedSegmentCount - 1)) * Constants.segmentSpacing
            HStack(spacing: Constants.segmentSpacing) {
                segment(count: normalCount, color: DesignColor.positive, availableWidth: availableWidth)
                segment(count: attentionCount, color: DesignColor.warning, availableWidth: availableWidth)
                segment(count: criticalCount, color: DesignColor.critical, availableWidth: availableWidth)
            }
            .clipShape(Capsule())
        }
        .frame(height: Constants.height)
    }

    @ViewBuilder
    private func segment(count: Int, color: Color, availableWidth: CGFloat) -> some View {
        if count > .zero {
            color
                .frame(width: max(Constants.minimumSegmentWidth, availableWidth * ratio(for: count)))
        }
    }

    private var totalCount: Int {
        max(1, normalCount + attentionCount + criticalCount)
    }

    private var populatedSegmentCount: Int {
        [normalCount, attentionCount, criticalCount].count { $0 > .zero }
    }

    private func ratio(for count: Int) -> CGFloat {
        CGFloat(count) / CGFloat(totalCount)
    }

    private enum Constants {
        static let height: CGFloat = 10
        static let segmentSpacing: CGFloat = 2
        static let minimumSegmentWidth: CGFloat = 4
    }
}
