import DesignSystem
import SwiftUI

struct DashboardSystemHealthCellsCard: View {
    let state: DashboardSystemHealthViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(spacing: Constants.spacing) {
                DashboardSystemHealthHeader(
                    title: rideDashboardLocalized(.rideDashboardSystemHealthCellsTitle),
                    state: state
                )
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
                Text(.rideDashboardSystemHealthCellDelta)
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
                Text(.rideDashboardSystemHealthCellsPackDistribution)
                Spacer()
                Text(rideDashboardLocalized(.rideDashboardSystemHealthCellsCount(state.cells.count)))
                    .monospacedDigit()
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(DesignColor.secondaryText)

            SegmentedDistributionBar(
                segments: [
                    .init(value: Double(normalCellCount), color: DesignColor.positive),
                    .init(value: Double(state.attentionCellCount), color: DesignColor.warning),
                    .init(value: Double(state.criticalCellCount), color: DesignColor.critical)
                ]
            )

            HStack(spacing: DesignSpace.extraSmall) {
                distributionMetric(
                    rideDashboardLocalized(.rideDashboardSystemHealthCellsNormal),
                    value: normalCellCount,
                    color: DesignColor.positive
                )
                distributionMetric(
                    rideDashboardLocalized(.rideDashboardSystemHealthCellsCheck),
                    value: state.attentionCellCount,
                    color: DesignColor.warning
                )
                distributionMetric(
                    rideDashboardLocalized(.rideDashboardSystemHealthCellsCritical),
                    value: state.criticalCellCount,
                    color: DesignColor.critical
                )
            }
        }
        .padding(DesignSpace.small)
        .background(DesignColor.elevatedSurface, in: RoundedRectangle(cornerRadius: DesignRadius.small))
    }

    private var extremes: some View {
        HStack(spacing: DesignSpace.small) {
            extremeMetric(
                title: rideDashboardLocalized(.rideDashboardSystemHealthCellsLowest),
                value: state.minimumCellText,
                systemImage: "arrow.down"
            )
            extremeMetric(
                title: rideDashboardLocalized(.rideDashboardSystemHealthCellsHighest),
                value: state.maximumCellText,
                systemImage: "arrow.up"
            )
        }
    }

    @ViewBuilder
    private var balancingStatus: some View {
        if state.balancingCellCount > .zero {
            Label(
                rideDashboardLocalized(.rideDashboardSystemHealthCellsBalancing(state.balancingCellCount)),
                systemImage: "arrow.triangle.2.circlepath"
            )
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignColor.informational)
                .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSpace.small) {
            ProgressView()
                .tint(DesignColor.informational)
            if !state.statusDetail.isEmpty {
                Text(state.statusDetail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var normalCellCount: Int {
        max(.zero, state.cells.count - state.attentionCellCount - state.criticalCellCount)
    }

    private var issueSummaryText: String {
        if state.criticalCellCount > .zero {
            return rideDashboardLocalized(.rideDashboardSystemHealthCellsCriticalStatus(state.criticalCellCount))
        }
        if state.attentionCellCount > .zero {
            return rideDashboardLocalized(.rideDashboardSystemHealthCellsCheckStatus(state.attentionCellCount))
        }
        return rideDashboardLocalized(.rideDashboardSystemHealthCellsUniform)
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
        rideDashboardLocalized(.rideDashboardSystemHealthCellsAccessibility(
            state.statusText,
            state.cellDeltaText,
            normalCellCount,
            state.attentionCellCount,
            state.criticalCellCount,
            state.minimumCellText,
            state.maximumCellText,
            state.balancingCellCount
        ))
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let minimumTextScale = 0.75
    }
}
