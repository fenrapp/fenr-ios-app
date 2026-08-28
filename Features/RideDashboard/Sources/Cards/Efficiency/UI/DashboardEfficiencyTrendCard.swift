import Charts
import DesignSystem
import SwiftUI

struct DashboardEfficiencyTrendCard: View {
    let state: DashboardEfficiencyViewData

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(alignment: .leading, spacing: Constants.spacing) {
                header
                if state.trendIsLoading {
                    ProgressView()
                        .tint(DesignColor.informational)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading efficiency trend")
                } else if state.trendPoints.isEmpty {
                    emptyState
                } else {
                    hero
                    trendChart
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var header: some View {
        DashboardTripCardHeader(title: "EFFICIENCY · TREND") {
            Text("LAST 10 TRIPS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraSmall) {
            Text(state.trendPoints.last?.efficiency.formatted(.number.precision(.fractionLength(0))) ?? "—")
                .font(.system(size: Constants.heroFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
            Text(state.unitText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private var trendChart: some View {
        Chart(state.trendPoints) { point in
            AreaMark(
                x: .value("Trip", point.date),
                y: .value("Efficiency", point.efficiency)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [DesignColor.informational.opacity(0.28), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            LineMark(
                x: .value("Trip", point.date),
                y: .value("Efficiency", point.efficiency)
            )
            .foregroundStyle(DesignColor.informational)
            .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            if point.id == state.trendPoints.last?.id {
                PointMark(
                    x: .value("Trip", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .foregroundStyle(DesignColor.positive)
                .symbolSize(Constants.lastPointSize)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(DesignColor.border)
                AxisValueLabel().foregroundStyle(DesignColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Constants.chartHeight)
        .accessibilityLabel("Efficiency across \(state.trendPoints.count) trips")
    }

    private var emptyState: some View {
        VStack(spacing: DesignSpace.small) {
            Image(systemName: state.hasConfirmedVehicle ? "chart.xyaxis.line" : "motorcycle")
                .font(.title2)
                .foregroundStyle(DesignColor.secondaryText)
            Text(state.hasConfirmedVehicle ? "NO QUALIFYING TRIPS YET" : "WAITING FOR BIKE IDENTITY")
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignColor.secondaryText)
            Text("Trips need at least 1 km and 90% power coverage.")
                .font(.caption2)
                .foregroundStyle(DesignColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accessibilityLabel: String {
        state.trendPoints.isEmpty
            ? "Efficiency trend has no qualifying trips"
            : "Efficiency trend, latest \(state.trendPoints.last?.efficiency ?? .zero) \(state.unitText)"
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let heroFontSize: CGFloat = 38
        static let chartHeight: CGFloat = 150
        static let lastPointSize: CGFloat = 70
    }
}
