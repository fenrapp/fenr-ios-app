import BikeDomain
import Testing

@Suite("Bike connection use cases")
struct BikeConnectionUseCaseTests {
    @Test("Use cases delegate and propagate errors")
    func useCasesDelegate() async throws {
        let repository = SpyBikeRepository()
        let vin = "FENRTEST000000001"
        try await ConnectToBikeUseCase(repository: repository).execute(vin: vin)
        try await DisconnectBikeUseCase(repository: repository).execute()
        try await RetryBikeSecurityHandshakeUseCase(repository: repository).execute()
        try await ReadBikeTelemetrySnapshotUseCase(repository: repository).execute()
        try await ReadBikeStatusSnapshotUseCase(repository: repository).execute()

        #expect(await repository.connectedVIN() == vin)
        #expect(await repository.didDisconnect())
        #expect(await repository.didRetrySecurityHandshake())
        #expect(await repository.didReadTelemetrySnapshot())
        #expect(await repository.didReadBikeStatusSnapshot())

        await repository.setError(SpyBikeRepositoryError.expected)
        await #expect(throws: SpyBikeRepositoryError.expected) {
            try await ConnectToBikeUseCase(repository: repository).execute(vin: vin)
        }
        await #expect(throws: SpyBikeRepositoryError.expected) {
            try await RetryBikeSecurityHandshakeUseCase(repository: repository).execute()
        }
        await #expect(throws: SpyBikeRepositoryError.expected) {
            try await ReadBikeTelemetrySnapshotUseCase(repository: repository).execute()
        }
        await #expect(throws: SpyBikeRepositoryError.expected) {
            try await ReadBikeStatusSnapshotUseCase(repository: repository).execute()
        }
    }

    @Test("PIN use case returns pin deriver value")
    func pinUseCase() {
        let pinDeriver = SpyBikePinDeriver()
        #expect(DeriveBikePinUseCase(pinDeriver: pinDeriver).execute(vin: "FENRTEST000000001") == "123456")
    }
}
