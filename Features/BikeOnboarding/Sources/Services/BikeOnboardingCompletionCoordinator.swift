import BikeDomain
import RuntimeConfiguration

enum BikeOnboardingCompletionEvent: Sendable {
    case completed(String)
}

@MainActor
public final class BikeOnboardingCompletionCoordinator {
    let events: AsyncStream<BikeOnboardingCompletionEvent>

    private let saveProfile: SaveBikeProfileUseCase
    private let timing: BikeOnboardingTiming
    private let eventContinuation: AsyncStream<BikeOnboardingCompletionEvent>.Continuation
    private var persistenceTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var completedVIN: String?
    private var requiresExplicitContinuation = false
    private var didPersist = false
    private var didRequestContinuation = false
    private var didDeliver = false

    public init(saveProfile: SaveBikeProfileUseCase, timing: BikeOnboardingTiming) {
        self.saveProfile = saveProfile
        self.timing = timing
        let eventChannel = AsyncStream<BikeOnboardingCompletionEvent>.makeStream()
        events = eventChannel.stream
        eventContinuation = eventChannel.continuation
    }

    deinit {
        persistenceTask?.cancel()
        transitionTask?.cancel()
        eventContinuation.finish()
    }

    func start(vin: String) {
        guard completedVIN == nil else { return }
        completedVIN = vin
        let saveProfile = saveProfile
        persistenceTask = Task { [weak self] in
            await saveProfile.execute(BikeProfile(vin: vin))
            guard !Task.isCancelled, let self, self.completedVIN == vin else { return }
            self.didPersist = true
            if self.requiresExplicitContinuation {
                self.deliverIfPossible()
            } else {
                self.scheduleAutomaticTransition()
            }
        }
    }

    func setRequiresExplicitContinuation(_ isRequired: Bool) {
        requiresExplicitContinuation = isRequired
        if isRequired {
            transitionTask?.cancel()
            transitionTask = nil
        } else if didPersist {
            scheduleAutomaticTransition()
        }
    }

    func continueFromSuccess() {
        didRequestContinuation = true
        deliverIfPossible()
    }

    private func scheduleAutomaticTransition() {
        guard didPersist, !didDeliver else { return }
        transitionTask?.cancel()
        let timing = timing
        transitionTask = Task { [weak self] in
            do {
                try await timing.sleep(FENRRuntimeConstants.Onboarding.successPresentationDelay)
            } catch {
                return
            }
            guard !Task.isCancelled, let self, !self.requiresExplicitContinuation else { return }
            self.deliverIfPossible(force: true)
        }
    }

    private func deliverIfPossible(force: Bool = false) {
        guard didPersist,
              !didDeliver,
              force || didRequestContinuation,
              let completedVIN else { return }
        didDeliver = true
        transitionTask?.cancel()
        transitionTask = nil
        eventContinuation.yield(.completed(completedVIN))
    }
}
