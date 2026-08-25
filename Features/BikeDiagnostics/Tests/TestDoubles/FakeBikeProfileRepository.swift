import BikeDomain

actor FakeBikeProfileRepository: BikeProfileRepository {
    private var profile: BikeProfile?
    private let loadDelay: Duration?
    private var didStartLoading = false
    private var didCancelLoading = false

    init(profile: BikeProfile? = nil, loadDelay: Duration? = nil) {
        self.profile = profile
        self.loadDelay = loadDelay
    }

    func loadProfile() async -> BikeProfile? {
        didStartLoading = true
        if let loadDelay {
            do {
                try await Task.sleep(for: loadDelay)
            } catch is CancellationError {
                didCancelLoading = true
                return nil
            } catch {
                return nil
            }
        }
        return profile
    }

    func saveProfile(_ profile: BikeProfile) async { self.profile = profile }
    func clearProfile() async { profile = nil }
    func loadStarted() -> Bool { didStartLoading }
    func loadWasCancelled() -> Bool { didCancelLoading }
}
