import SettingsDomain

public struct BikeLockSecurityOptionProvider: Sendable {
    public let options: [BikeLockSecurityOptionViewData]

    public init() {
        options = [
            .init(
                id: BikeLockSecurityMode.pinAndFaceID.rawValue,
                title: rideDashboardLocalized(.rideDashboardBikeLockSecurityFaceIDTitle),
                detail: rideDashboardLocalized(.rideDashboardBikeLockSecurityFaceIDDetail),
                requiresPIN: true
            ),
            .init(
                id: BikeLockSecurityMode.pin.rawValue,
                title: rideDashboardLocalized(.rideDashboardBikeLockSecurityPinTitle),
                detail: rideDashboardLocalized(.rideDashboardBikeLockSecurityPinDetail),
                requiresPIN: true
            ),
            .init(
                id: BikeLockSecurityMode.withoutPIN.rawValue,
                title: rideDashboardLocalized(.rideDashboardBikeLockSecurityNoneTitle),
                detail: rideDashboardLocalized(.rideDashboardBikeLockSecurityNoneDetail),
                requiresPIN: false
            )
        ]
    }
}
