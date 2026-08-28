import SwiftUI

struct RideHistoryDetailContent: View {
    let state: RideHistoryDetailViewState

    var body: some View {
        switch state.status {
        case .idle, .loading:
            ProgressView("Loading ride details")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unavailable:
            ContentUnavailableView(
                "Ride Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("This saved ride could not be loaded.")
            )
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            Section {
                RideHistoryDetailHeader(state: state)
            }

            metricSection(title: "Overview", metrics: state.overviewMetrics)
            metricSection(title: "Energy", metrics: state.energyMetrics)

            if hasChartData {
                Section("Energy Profile") {
                    RideHistoryEnergyChart(state: state)
                        .padding(.vertical, Constants.chartVerticalPadding)
                }
            }

            if !state.comparisons.isEmpty {
                Section {
                    ForEach(state.comparisons) { comparison in
                        RideHistoryComparisonRow(comparison: comparison)
                    }
                } header: {
                    Text("Recent Comparison")
                } footer: {
                    if let detail = state.comparisonDetail {
                        Text(detail)
                    }
                }
            }

            metricSection(title: "Power", metrics: state.performanceMetrics)
            metricSection(title: "Ride Dynamics", metrics: state.dynamicsMetrics)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func metricSection(
        title: String,
        metrics: [RideHistoryDetailViewState.Metric]
    ) -> some View {
        if !metrics.isEmpty {
            Section(title) {
                ForEach(metrics) { metric in
                    RideHistoryMetricRow(metric: metric)
                }
            }
        }
    }

    private var hasChartData: Bool {
        !state.batteryPoints.isEmpty || !state.efficiencyPoints.isEmpty
    }

    private enum Constants {
        static let chartVerticalPadding: CGFloat = 8
    }
}
