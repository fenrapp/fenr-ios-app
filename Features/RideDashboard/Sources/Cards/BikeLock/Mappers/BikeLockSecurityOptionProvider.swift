import SettingsDomain

public struct BikeLockSecurityOptionProvider: Sendable {
    public let options: [BikeLockSecurityOptionViewData]

    public init() {
        options = [
            .init(
                id: BikeLockSecurityMode.pinAndFaceID.rawValue,
                title: "PIN + Face ID",
                detail: "Use Face ID first, with your PIN as a fallback.",
                requiresPIN: true
            ),
            .init(
                id: BikeLockSecurityMode.pin.rawValue,
                title: "PIN",
                detail: "Enter a 6-digit PIN whenever you unlock.",
                requiresPIN: true
            ),
            .init(
                id: BikeLockSecurityMode.withoutPIN.rawValue,
                title: "No PIN",
                detail: "Lock and unlock immediately from the card.",
                requiresPIN: false
            )
        ]
    }
}
