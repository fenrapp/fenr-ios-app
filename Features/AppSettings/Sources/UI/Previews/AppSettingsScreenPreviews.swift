import SwiftUI

#if DEBUG && os(iOS)
#Preview("Live Activities enabled") {
    NavigationStack {
        LiveActivitySettingsContent(
            state: SettingsScreenPreviewData.liveActivities(isEnabled: true),
            setEnabled: { _ in }, setActivityEnabled: { _, _ in }, selectPresentation: { _, _ in }
        )
    }
}

#Preview("Live Activities disabled - accessibility") {
    NavigationStack {
        LiveActivitySettingsContent(
            state: SettingsScreenPreviewData.liveActivities(isEnabled: false),
            setEnabled: { _ in }, setActivityEnabled: { _, _ in }, selectPresentation: { _, _ in }
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Navigation appearance") {
    NavigationStack {
        NavigationAppearanceSettingsContent(
            lineStyles: SettingsScreenPreviewData.lineStyles,
            setColor: { _, _ in }, selectThickness: { _, _ in }
        )
    }
}

private enum SettingsScreenPreviewData {
    static func liveActivities(isEnabled: Bool) -> LiveActivitySettingsViewState {
        .init(isEnabled: isEnabled, activities: [
            .init(
                id: "riding", title: .appSettingsLiveActivitiesRiding,
                detail: .appSettingsLiveActivitiesRidingDetail,
                isEnabled: false, presentation: presentation
            ),
            .init(
                id: "charging",
                title: .appSettingsLiveActivitiesCharging,
                detail: .appSettingsLiveActivitiesChargingDetail,
                isEnabled: true,
                presentation: presentation
            )
        ])
    }

    static let lineStyles: [NavigationLineStyleViewData] = [
        .init(
            id: "pendingRoute", title: .appSettingsNavigationLinePending,
            color: .init(red: 0.1, green: 0.4, blue: 0.95), thickness: thickness
        ),
        .init(
            id: "activeSection", title: .appSettingsNavigationLineActive,
            color: .init(red: 0.95, green: 0.45, blue: 0.1), thickness: thickness
        ),
        .init(
            id: "completedRoute", title: .appSettingsNavigationLineCompleted,
            color: .init(red: 0.2, green: 0.7, blue: 0.4), thickness: thickness
        ),
        .init(
            id: "recording", title: .appSettingsNavigationLineRecording,
            color: .init(red: 0.9, green: 0.2, blue: 0.15), thickness: thickness
        ),
        .init(
            id: "connector", title: .appSettingsNavigationLineConnector,
            color: .init(red: 0.5, green: 0.5, blue: 0.5), thickness: thickness
        )
    ]
    static let thickness = AppSettingsSelectionViewState(selectedID: "regular", options: [
        .init(id: "thin", title: .appSettingsNavigationThicknessThin),
        .init(id: "regular", title: .appSettingsNavigationThicknessRegular),
        .init(id: "thick", title: .appSettingsNavigationThicknessThick)
    ])
    static let presentation = AppSettingsSelectionViewState(selectedID: "summary", options: [
        .init(id: "summary", title: .appSettingsLiveActivitiesViewSummary),
        .init(id: "detailed", title: .appSettingsLiveActivitiesViewDetailed)
    ])
}
#endif
