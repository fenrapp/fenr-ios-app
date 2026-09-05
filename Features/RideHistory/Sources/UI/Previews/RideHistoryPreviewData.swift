import Foundation

#if DEBUG
enum RideHistoryPreviewData {
    static let firstRideID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let secondRideID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
    static let thirdRideID = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()

    static let summary = RideHistoryViewState.Summary(
        rideCountText: "24 rides",
        distanceText: "1,286 km",
        durationText: "31 hr, 42 min",
        averageSpeedText: "41 km/h",
        maximumSpeedText: "94 km/h"
    )

    static let rows = [
        RideHistoryViewState.Row(
            id: firstRideID,
            dateText: "Aug 28, 2026",
            timeText: "19:41",
            distanceText: "29.4 km",
            durationText: "00:38",
            efficiencyText: "64 Wh/km",
            accessibilityLabel: "Ride on Aug 28, 2026 at 19:41, 29.4 km, 00:38, 64 Wh/km"
        ),
        RideHistoryViewState.Row(
            id: secondRideID,
            dateText: "Aug 28, 2026",
            timeText: "08:12",
            distanceText: "18.7 km",
            durationText: "00:26",
            efficiencyText: "71 Wh/km",
            accessibilityLabel: "Ride on Aug 28, 2026 at 08:12, 18.7 km, 00:26, 71 Wh/km"
        ),
        RideHistoryViewState.Row(
            id: thirdRideID,
            dateText: "Aug 27, 2026",
            timeText: "17:04",
            distanceText: "42 km",
            durationText: "00:51",
            efficiencyText: "Efficiency unavailable",
            accessibilityLabel: "Ride on Aug 27, 2026 at 17:04, 42 km, 00:51, efficiency unavailable"
        )
    ]

    static let listState = RideHistoryViewState(
        status: .loaded,
        summary: summary,
        daySections: [
            .init(id: "2026-08-28", title: "Aug 28, 2026", rides: Array(rows.prefix(2))),
            .init(id: "2026-08-27", title: "Aug 27, 2026", rides: [rows[2]])
        ]
    )

    static let overviewMetrics = [
        metric(id: "duration", symbol: "clock", label: "Ride Time", value: "00:38"),
        metric(
            id: "averageSpeed",
            symbol: "gauge.with.dots.needle.33percent",
            label: "Average Speed",
            value: "46 km/h"
        ),
        metric(
            id: "maximumSpeed",
            symbol: "gauge.with.dots.needle.67percent",
            label: "Maximum Speed",
            value: "91 km/h"
        )
    ]

    static let energyMetrics = [
        metric(id: "used", symbol: "bolt.fill", label: "Energy Used", value: "1.9 kWh"),
        metric(id: "recovered", symbol: "arrow.uturn.backward.circle", label: "Recovered", value: "184 Wh"),
        metric(id: "net", symbol: "equal.circle", label: "Net Energy", value: "1.7 kWh"),
        metric(id: "efficiency", symbol: "leaf", label: "Efficiency", value: "64 Wh/km"),
        metric(
            id: "batteryChange",
            symbol: "battery.50percent",
            label: "Battery",
            value: "82% → 61%",
            detail: "21 percentage points used"
        )
    ]

    static let comparisons = [
        RideHistoryDetailViewState.Comparison(
            id: "distance",
            label: "Distance",
            value: "+18%",
            detail: "farther",
            emphasis: .neutral
        ),
        RideHistoryDetailViewState.Comparison(
            id: "efficiency",
            label: "Efficiency",
            value: "+9%",
            detail: "more efficient",
            emphasis: .positive
        ),
        RideHistoryDetailViewState.Comparison(
            id: "recovery",
            label: "Regeneration",
            value: "-3 pp",
            detail: "less recovered",
            emphasis: .negative
        )
    ]

    static let detailState = RideHistoryDetailViewState(
        status: .loaded,
        rideID: firstRideID,
        title: "Friday, August 28, 2026",
        subtitle: "19:41–20:19",
        distanceText: "29.4 km",
        overviewMetrics: overviewMetrics,
        energyMetrics: energyMetrics,
        performanceMetrics: [
            metric(id: "peakUse", symbol: "bolt.badge.clock.fill", label: "Peak Use", value: "18.4 kW"),
            metric(
                id: "peakRegen",
                symbol: "bolt.trianglebadge.exclamationmark.fill",
                label: "Peak Regen",
                value: "6.2 kW"
            )
        ],
        dynamicsMetrics: [
            metric(id: "leftLean", symbol: "angle", label: "Maximum Left Lean", value: "31.2°"),
            metric(id: "rightLean", symbol: "angle", label: "Maximum Right Lean", value: "34.8°")
        ],
        comparisons: comparisons,
        comparisonDetail: "Compared with up to 10 previous rides",
        batteryPoints: chartPoints(values: [82, 79, 76, 71, 66, 61]),
        efficiencyPoints: chartPoints(values: [66, 71, 58, -12, 75, 64]),
        distanceUnit: "km",
        efficiencyUnit: "Wh/km"
    )

    private static func metric(
        id: String,
        symbol: String,
        label: String,
        value: String,
        detail: String? = nil
    ) -> RideHistoryDetailViewState.Metric {
        .init(id: id, symbolName: symbol, label: label, value: value, detail: detail)
    }

    private static func chartPoints(values: [Double]) -> [RideHistoryDetailViewState.ChartPoint] {
        values.enumerated().map { index, value in
            .init(id: UUID(), distance: Double(index) * 5.8, value: value)
        }
    }
}
#endif
