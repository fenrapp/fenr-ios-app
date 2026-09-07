import Foundation

final class RideNavigationOperationStore: @unchecked Sendable {
    enum Kind: CaseIterable, Hashable {
        case vehicleObservation
        case locationObservation
        case clock
        case search
        case route
        case externalLink
        case trailExit
        case initialSettings
        case settingsObservation
        case settingsSave
        case trailPreparation
        case voiceAnnouncement
        case feedback
    }

    private var tasks: [Kind: Task<Void, Never>] = [:]
    private var generations: [Kind: UInt] = [:]
    private(set) var lifecycleGeneration: UInt = 0

    subscript(kind: Kind) -> Task<Void, Never>? {
        get { tasks[kind] }
        set { tasks[kind] = newValue }
    }

    func startLifecycle() -> UInt {
        lifecycleGeneration &+= 1
        return lifecycleGeneration
    }

    func begin(_ kind: Kind) -> UInt {
        tasks[kind]?.cancel()
        generations[kind, default: 0] &+= 1
        return generations[kind, default: 0]
    }

    func isCurrent(_ kind: Kind, generation: UInt, lifecycle: UInt) -> Bool {
        generations[kind, default: 0] == generation && lifecycleGeneration == lifecycle
    }

    func isCurrent(_ kind: Kind, generation: UInt) -> Bool {
        generations[kind, default: 0] == generation
    }

    func invalidate(_ kind: Kind) {
        tasks[kind]?.cancel()
        tasks[kind] = nil
        generations[kind, default: 0] &+= 1
    }

    func invalidateAll(preserving preservedKinds: Set<Kind> = []) {
        lifecycleGeneration &+= 1
        for kind in Kind.allCases where !preservedKinds.contains(kind) {
            invalidate(kind)
        }
    }
}
