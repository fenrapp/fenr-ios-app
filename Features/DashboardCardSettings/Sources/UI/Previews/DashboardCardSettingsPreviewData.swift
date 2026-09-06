import SwiftUI

#if DEBUG
enum DashboardCardSettingsPreviewData {
    static let fixedCards: [DashboardCardFixedRowViewData] = [
        .init(
            id: "dashboard", title: "Riding dashboard", detail: "Speed, battery and riding mode",
            thumbnail: .init(style: .gauge, systemImage: "speedometer", accent: .accent)
        ),
        .init(
            id: "charging", title: "Charging", detail: "Charging progress and controls",
            thumbnail: .init(style: .charging, systemImage: "bolt.fill", accent: .positive)
        )
    ]
    static let pages: [DashboardCardPageRowViewData] = [
        .init(
            id: "trip", title: "Current trip", isVisible: true, canHide: false,
            thumbnail: .init(style: .metrics, systemImage: "flag.checkered", accent: .accent)
        ),
        .init(
            id: "efficiency", title: "Energy and efficiency", isVisible: false, canHide: true,
            thumbnail: .init(style: .chart, systemImage: "leaf.fill", accent: .positive)
        )
    ]
    static let sections: [DashboardCardSectionRowViewData] = [
        rideData(pages: pages),
        .init(
            id: "compass", title: "Compass", detail: "Heading and orientation", isVisible: false,
            thumbnail: .init(style: .compass, systemImage: "location.north.fill", accent: .informational),
            pages: []
        ),
        .init(
            id: "lock", title: "Bike Lock", detail: "Protected unlock controls", isVisible: true,
            isVisibilityEnabled: false,
            disabledVisibilityHint: "Required while unlock protection is configured",
            thumbnail: .init(style: .lock, systemImage: "lock.fill", accent: .accent), pages: []
        )
    ]

    static func rideData(pages: [DashboardCardPageRowViewData]) -> DashboardCardSectionRowViewData {
        .init(
            id: "rideData", title: "Ride data", detail: "Trip and efficiency cards", isVisible: true,
            thumbnail: .init(style: .metrics, systemImage: "chart.bar.fill", accent: .informational),
            pages: pages
        )
    }
}
#endif
