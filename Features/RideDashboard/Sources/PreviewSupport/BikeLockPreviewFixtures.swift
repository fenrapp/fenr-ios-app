#if DEBUG
enum BikeLockPreviewFixtures {
    static let options = BikeLockSecurityOptionProvider().options

    static let unlocked = BikeLockCardViewState(
        isAvailable: true, isActionEnabled: true, isConfigured: true,
        statusText: "Unlocked", actionTitle: "Lock bike"
    )

    static let locked = BikeLockCardViewState(
        isAvailable: true, isLocked: true, isActionEnabled: true, isConfigured: true,
        statusText: "Locked", actionTitle: "Unlock bike"
    )

    static let needsSetup = BikeLockCardViewState(
        isAvailable: true, isActionEnabled: true,
        statusText: "Ready to set up", actionTitle: "Set up Bike Lock"
    )

    static let working = BikeLockCardViewState(
        isAvailable: true, isWorking: true, isConfigured: true,
        statusText: "Locking bike", actionTitle: "Lock bike"
    )

    static let failure = BikeLockCardViewState(
        isAvailable: true, isLocked: true, isActionEnabled: true, isConfigured: true,
        statusText: "Locked", actionTitle: "Try again",
        errorText: "The bike did not confirm the change. Please try again."
    )
}
#endif
