struct RideNavigationGuidanceVisibilityPolicy {
    func showsGuidance(
        isFocus: Bool,
        showsGuidanceInFocus: Bool,
        isRerouting: Bool,
        guidance: RideNavigationGuidance?
    ) -> Bool {
        guard isFocus, !showsGuidanceInFocus else { return true }
        return isRerouting || guidance?.emphasis == .warning
    }

    func showsForkGuidance(
        isFocus: Bool,
        showsGuidanceInFocus: Bool,
        guidance: RideNavigationForkGuidance
    ) -> Bool {
        !isFocus || showsGuidanceInFocus || guidance.emphasis == .warning
    }
}
