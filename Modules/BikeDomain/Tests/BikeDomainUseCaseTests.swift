import BikeDomain
import Testing

@Suite("Bike domain use cases")
struct BikeDomainUseCaseTests {
    @Test("Use cases delegate and propagate errors")
    func useCasesDelegate() async throws {
        let repository = SpyRepository()
        try await ConnectToBikeUseCase(repository: repository).execute(vin: "VIN123")
        try await DisconnectBikeUseCase(repository: repository).execute()
        try await RetryBikeSecurityHandshakeUseCase(repository: repository).execute()
        try await ReadBikeTelemetrySnapshotUseCase(repository: repository).execute()
        try await ReadBikeStatusSnapshotUseCase(repository: repository).execute()

        #expect(await repository.connectedVIN() == "VIN123")
        #expect(await repository.didDisconnect())
        #expect(await repository.didRetrySecurityHandshake())
        #expect(await repository.didReadTelemetrySnapshot())
        #expect(await repository.didReadBikeStatusSnapshot())

        await repository.setError(SpyError.expected)
        await #expect(throws: SpyError.expected) {
            try await ConnectToBikeUseCase(repository: repository).execute(vin: "VIN123")
        }
        await #expect(throws: SpyError.expected) {
            try await RetryBikeSecurityHandshakeUseCase(repository: repository).execute()
        }
        await #expect(throws: SpyError.expected) {
            try await ReadBikeTelemetrySnapshotUseCase(repository: repository).execute()
        }
        await #expect(throws: SpyError.expected) {
            try await ReadBikeStatusSnapshotUseCase(repository: repository).execute()
        }
    }

    @Test("PIN use case returns pin deriver value")
    func pinUseCase() {
        let pinDeriver = SpyBikePinDeriver()
        #expect(DeriveBikePinUseCase(pinDeriver: pinDeriver).execute(vin: "VIN") == "123456")
    }
}
