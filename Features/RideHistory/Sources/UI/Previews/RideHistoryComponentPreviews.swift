import SwiftUI

#if DEBUG
#Preview("Ride summary and rows") {
    List {
        Section {
            RideHistorySummaryHeader(summary: RideHistoryPreviewData.summary)
        }
        Section("Aug 28, 2026") {
            RideHistoryRow(ride: RideHistoryPreviewData.rows[0], isDeleting: false)
            RideHistoryRow(ride: RideHistoryPreviewData.rows[1], isDeleting: true)
        }
    }
    .listStyle(.insetGrouped)
}

#Preview("Detail header and metrics") {
    List {
        Section {
            RideHistoryDetailHeader(state: RideHistoryPreviewData.detailState)
        }
        Section("Overview") {
            ForEach(RideHistoryPreviewData.overviewMetrics) { metric in
                RideHistoryMetricRow(metric: metric)
            }
        }
        Section("Recent Comparison") {
            ForEach(RideHistoryPreviewData.comparisons) { comparison in
                RideHistoryComparisonRow(comparison: comparison)
            }
        }
    }
    .listStyle(.insetGrouped)
}

#Preview("Energy chart") {
    List {
        Section("Energy Profile") {
            RideHistoryEnergyChart(state: RideHistoryPreviewData.detailState)
                .padding(.vertical)
        }
    }
    .listStyle(.insetGrouped)
}

#Preview("Ride row accessibility") {
    List {
        RideHistoryRow(ride: RideHistoryPreviewData.rows[0], isDeleting: false)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
