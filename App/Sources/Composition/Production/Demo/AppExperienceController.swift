import Combine
import Foundation

@MainActor
final class AppExperienceController: ObservableObject {
    @Published private(set) var experience: AppExperience?
    @Published private(set) var isBusy = false
    @Published private(set) var failure: AppExperienceFailure?
    var hasError: Bool { failure != nil }
    @Published var showsIntroduction = false

    private let selectionStore: DemoSelectionStore
    private let makeReal: @MainActor () throws -> AppExperience
    private let makeDemo: @MainActor (DemoIdentity) async throws -> AppExperience
    private let discardDemo: @MainActor (DemoIdentity) async throws -> Void
    private var transitionTask: Task<Void, Never>?
    private var pendingIdentity: DemoIdentity?

    init(
        selectionStore: DemoSelectionStore,
        makeReal: @escaping @MainActor () throws -> AppExperience,
        makeDemo: @escaping @MainActor (DemoIdentity) async throws -> AppExperience,
        discardDemo: @escaping @MainActor (DemoIdentity) async throws -> Void
    ) {
        self.selectionStore = selectionStore
        self.makeReal = makeReal
        self.makeDemo = makeDemo
        self.discardDemo = discardDemo
    }

    deinit { transitionTask?.cancel() }

    func restore() {
        guard experience == nil else { return }
        transition { controller in
            if let identity = try controller.selectionStore.load() {
                controller.pendingIdentity = identity
                let demo = try await controller.makeDemo(identity)
                try await controller.install(demo)
            } else {
                controller.experience = try controller.buildReal()
            }
        }
    }

    func exploreDemo() {
        guard !isBusy else { return }
        failure = nil
        showsIntroduction = true
    }

    func cancelIntroduction() {
        guard !isBusy else { return }
        if hasError {
            changeBike()
            return
        }
        showsIntroduction = false
        if experience?.demoViewModel == nil {
            experience?.root.featureStore.onboardingViewModel.startObserving()
        }
    }

    func startDemo() {
        transition { controller in
            let identity = try controller.pendingIdentity
                ?? controller.selectionStore.loadSavedIdentity()
                ?? controller.selectionStore.makeIdentity()
            controller.pendingIdentity = identity
            let previous = controller.experience
            controller.experience = nil
            await previous?.close()
            try Task.checkCancellation()
            let demo = try await controller.makeDemo(identity)
            do {
                try Task.checkCancellation()
                try controller.selectionStore.save(identity)
            } catch {
                await demo.close()
                throw error
            }
            try await controller.install(demo)
            controller.showsIntroduction = false
        }
    }

    func changeBike() {
        transition { controller in
            let previous = controller.experience
            controller.experience = nil
            await previous?.close()
            try Task.checkCancellation()
            if previous?.demoViewModel == nil,
               let identity = controller.pendingIdentity,
               try controller.selectionStore.loadSavedIdentity()?.id != identity.id {
                try await controller.discardDemo(identity)
            }
            try Task.checkCancellation()
            try controller.selectionStore.deactivate()
            controller.pendingIdentity = nil
            controller.showsIntroduction = false
            controller.experience = try controller.buildReal()
        }
    }

    private func buildReal() throws -> AppExperience {
        do {
            return try makeReal()
        } catch {
            throw AppExperienceFailure.storage
        }
    }

    private func install(_ newExperience: AppExperience) async throws {
        guard !Task.isCancelled else {
            await newExperience.close()
            throw CancellationError()
        }
        experience = newExperience
    }

    private func transition(_ operation: @escaping @MainActor (AppExperienceController) async throws -> Void) {
        guard transitionTask == nil else { return }
        isBusy = true
        failure = nil
        transitionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isBusy = false
                self.transitionTask = nil
            }
            do {
                try Task.checkCancellation()
                try await operation(self)
            } catch is CancellationError {
                return
            } catch {
                self.failure = (error as? AppExperienceFailure) ?? .demo
            }
        }
    }
}
