@testable import RideNavigation
import Testing

struct RideNavigationGuidanceVisibilityPolicyTests {
    private let policy = RideNavigationGuidanceVisibilityPolicy()

    @Test("Focus hides ordinary guidance unless enabled")
    func focusGuidanceSetting() {
        let standard = RideNavigationGuidance(
            text: "Continue",
            detail: "200 m",
            systemImage: "arrow.up",
            emphasis: .standard
        )

        #expect(!policy.showsGuidance(
            isFocus: true,
            showsGuidanceInFocus: false,
            isRerouting: false,
            guidance: standard
        ))
        #expect(policy.showsGuidance(
            isFocus: true,
            showsGuidanceInFocus: true,
            isRerouting: false,
            guidance: standard
        ))
        #expect(policy.showsGuidance(
            isFocus: false,
            showsGuidanceInFocus: false,
            isRerouting: false,
            guidance: standard
        ))
    }

    @Test("Focus preserves critical navigation feedback")
    func focusPreservesWarningsAndRerouting() {
        let warning = RideNavigationGuidance(
            text: "Off route",
            detail: "Return",
            systemImage: "exclamationmark.triangle",
            emphasis: .warning
        )
        let standardFork = RideNavigationForkGuidance(
            instructionText: "Keep left",
            distanceText: "40 m",
            systemImage: "arrow.turn.up.left"
        )
        let warningFork = RideNavigationForkGuidance(
            instructionText: "Wrong turn",
            distanceText: "Return",
            systemImage: "arrow.uturn.backward",
            emphasis: .warning
        )

        #expect(policy.showsGuidance(
            isFocus: true,
            showsGuidanceInFocus: false,
            isRerouting: false,
            guidance: warning
        ))
        #expect(policy.showsGuidance(
            isFocus: true,
            showsGuidanceInFocus: false,
            isRerouting: true,
            guidance: nil
        ))
        #expect(!policy.showsForkGuidance(
            isFocus: true,
            showsGuidanceInFocus: false,
            guidance: standardFork
        ))
        #expect(policy.showsForkGuidance(
            isFocus: true,
            showsGuidanceInFocus: false,
            guidance: warningFork
        ))
    }
}
