import BikeDomain
import Testing

@MainActor
@Suite("Bike setup flow")
struct BikeSetupFlowControllerTests {
    @Test("Loads a completed profile on a subsequent launch")
    func loadsCompletedProfile() async {
        let repository = SetupProfileRepository(profile: .init(vin: "FENRTEST000000001"))
        let controller = makeController(repository: repository)

        await controller.load()

        #expect(controller.isLoaded)
        #expect(controller.isCompleted)
        #expect(controller.configuredVIN == "FENRTEST000000001")
    }

    @Test("Debug onboarding ignores a previously stored profile")
    func forceOnboardingIgnoresPersistedProfile() async {
        let repository = SetupProfileRepository(profile: .init(vin: "FENRTEST000000001"))
        let controller = makeController(repository: repository, forceOnboarding: true)

        await controller.load()

        #expect(controller.isLoaded)
        #expect(!controller.isCompleted)
        #expect(controller.configuredVIN == nil)
    }

    @Test("Changing bike clears the configured profile")
    func resetClearsProfile() async {
        let repository = SetupProfileRepository(profile: .init(vin: "FENRTEST000000001"))
        let controller = makeController(repository: repository)
        await controller.load()

        await controller.reset()

        #expect(!controller.isCompleted)
        #expect(controller.configuredVIN == nil)
        #expect(await repository.loadProfile() == nil)
    }

    private func makeController(
        repository: SetupProfileRepository,
        forceOnboarding: Bool = false
    ) -> BikeSetupFlowController {
        BikeSetupFlowController(
            useCases: .init(
                load: .init(repository: repository),
                clear: .init(repository: repository)
            ),
            forceOnboarding: forceOnboarding
        )
    }
}
