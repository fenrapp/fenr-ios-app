import BikeDomain
import Combine

@MainActor
final class BikeSetupFlowController: ObservableObject {
    @Published private(set) var isCompleted = false
    @Published private(set) var isLoaded = false

    private let useCases: BikeProfileUseCases
    private let forceOnboarding: Bool
    private var profile: BikeProfile?

    init(useCases: BikeProfileUseCases, forceOnboarding: Bool) {
        self.useCases = useCases
        self.forceOnboarding = forceOnboarding
    }

    var configuredVIN: String? { profile?.vin }

    func load() async {
        defer { isLoaded = true }
        guard !forceOnboarding, let profile = await useCases.load.execute() else { return }

        self.profile = profile
        isCompleted = true
    }

    func complete(vin: String) {
        profile = BikeProfile(vin: vin)
        isCompleted = true
    }

    func reset() async {
        await useCases.clear.execute()
        profile = nil
        isCompleted = false
    }
}
