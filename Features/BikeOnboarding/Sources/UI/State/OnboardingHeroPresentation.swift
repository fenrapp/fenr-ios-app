import Foundation

enum OnboardingHeroPresentationPhase: Int, Comparable, Sendable {
    case initial
    case light
    case photo
    case connected
    case riding
    case detail
    case complete

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func includes(_ phase: Self) -> Bool {
        self >= phase
    }
}

struct OnboardingHeroTimeline: Sendable {
    struct Step: Sendable {
        let phase: OnboardingHeroPresentationPhase
        let delay: Duration
        let animationDuration: TimeInterval
    }

    let steps: [Step]

    static let standard = OnboardingHeroTimeline(steps: [
        Step(phase: .light, delay: .zero, animationDuration: 0.18),
        Step(phase: .photo, delay: .milliseconds(160), animationDuration: 0.7),
        Step(phase: .connected, delay: .milliseconds(270), animationDuration: 0.32),
        Step(phase: .riding, delay: .milliseconds(70), animationDuration: 0.32),
        Step(phase: .detail, delay: .milliseconds(120), animationDuration: 0.25),
        Step(phase: .complete, delay: .milliseconds(80), animationDuration: 0.2)
    ])
}
