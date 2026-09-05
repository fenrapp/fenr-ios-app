import Combine
import Foundation

@MainActor
final class AppExperienceController: ObservableObject {
    @Published private(set) var experience: AppExperience?
    @Published private(set) var isBusy = false
    @Published private(set) var hasError = false
    @Published var showsIntroduction = false

    private let selectionStore: DemoSelectionStore
    private let makeReal: @MainActor () -> AppExperience
    private let makeDemo: @MainActor (DemoIdentity) async throws -> AppExperience
    private let discardDemo: @MainActor (DemoIdentity) async throws -> Void
    private var transitionTask: Task<Void, Never>?
    private var pendingIdentity: DemoIdentity?

    init(
        selectionStore: DemoSelectionStore,
        makeReal: @escaping @MainActor () -> AppExperience,
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
                controller.experience = try await controller.makeDemo(identity)
            } else {
                controller.experience = controller.makeReal()
            }
        }
    }

    func exploreDemo() {
        guard !isBusy else { return }
        hasError = false
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
            let demo = try await controller.makeDemo(identity)
            try controller.selectionStore.save(identity)
            controller.experience = demo
            controller.showsIntroduction = false
        }
    }

    func changeBike() {
        transition { controller in
            let previous = controller.experience
            controller.experience = nil
            await previous?.close()
            if previous?.demoViewModel == nil,
               let identity = controller.pendingIdentity,
               try controller.selectionStore.loadSavedIdentity()?.id != identity.id {
                try await controller.discardDemo(identity)
            }
            try controller.selectionStore.deactivate()
            controller.pendingIdentity = nil
            controller.showsIntroduction = false
            controller.experience = controller.makeReal()
        }
    }

    private func transition(_ operation: @escaping @MainActor (AppExperienceController) async throws -> Void) {
        guard transitionTask == nil else { return }
        isBusy = true
        hasError = false
        transitionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isBusy = false
                self.transitionTask = nil
            }
            do {
                try await operation(self)
            } catch {
                self.hasError = true
            }
        }
    }
}
