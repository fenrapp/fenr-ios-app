import DesignSystem
import SwiftUI

struct RideHistoryDetailContent: View {
    let state: RideHistoryDetailViewState
    var retry: () -> Void = {}

    var body: some View {
        switch state.status {
        case .failed:
            ContentUnavailableView {
                Label(.rideHistoryDetailReadErrorTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(verbatim: state.loadErrorMessage ?? "")
            } actions: {
                Button(.rideHistoryRetry, action: retry)
                    .accessibilityIdentifier("rideHistory.detail.retry")
            }
        case .idle, .loading:
            ProgressView(.rideHistoryLoadingDetails)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unavailable:
            ContentUnavailableView(
                .rideHistoryRideUnavailable,
                systemImage: "exclamationmark.triangle",
                description: Text(.rideHistoryRideUnavailableDescription)
            )
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            if let message = state.loadErrorMessage {
                Section { RideHistoryReadErrorNotice(message: message, retry: retry) }
            }
            Section {
                RideHistoryDetailHeader(state: state)
            }

            metricSection(title: .rideHistorySectionOverview, metrics: state.overviewMetrics)
            metricSection(title: .rideHistorySectionEnergy, metrics: state.energyMetrics)

            if hasChartData {
                Section(.rideHistorySectionEnergyProfile) {
                    RideHistoryEnergyChart(state: state)
                        .padding(.vertical, DesignSpace.extraSmall)
                }
            }

            if !state.comparisons.isEmpty {
                Section {
                    ForEach(state.comparisons) { comparison in
                        RideHistoryComparisonRow(comparison: comparison)
                    }
                } header: {
                    Text(.rideHistorySectionRecentComparison)
                } footer: {
                    if let detail = state.comparisonDetail {
                        Text(detail)
                    }
                }
            }

            metricSection(title: .rideHistorySectionPower, metrics: state.performanceMetrics)
            metricSection(title: .rideHistorySectionRideDynamics, metrics: state.dynamicsMetrics)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func metricSection(
        title: LocalizedStringResource,
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
}
