import Testing
import TestSupport

@MainActor
@Suite("Bike Lock authentication lifecycle")
struct LocalAuthenticationBikeLockAuthenticatorTests {
    @Test("Every authentication attempt receives a fresh context")
    func createsFreshContexts() async throws {
        let factory = FakeBikeLockAuthenticationContextFactory()
        let authenticator = LocalAuthenticationBikeLockAuthenticator(makeContext: factory.make)

        #expect(try await authenticator.authenticate(reason: "First attempt"))
        #expect(try await authenticator.authenticate(reason: "Second attempt"))

        let contexts = factory.contexts
        #expect(contexts.count == 2)
        #expect(contexts.map(\.requestedReasons) == [["First attempt"], ["Second attempt"]])
        #expect(contexts.allSatisfy { $0.invalidationCount == 0 })
    }

    @Test("An already cancelled request does not create an authentication context")
    func skipsCancelledRequest() async throws {
        let factory = FakeBikeLockAuthenticationContextFactory()
        let authenticator = LocalAuthenticationBikeLockAuthenticator(makeContext: factory.make)
        let operation = Task { try await authenticator.authenticate(reason: "Cancelled attempt") }
        operation.cancel()

        await #expect(throws: CancellationError.self) { try await operation.value }
        #expect(factory.contexts.isEmpty)
    }

    @Test("Cancellation invalidates the context and rejects a late successful result")
    func rejectsLateAuthenticationAfterCancellation() async throws {
        let context = ControlledBikeLockAuthenticationContext()
        let authenticator = LocalAuthenticationBikeLockAuthenticator(makeContext: { context })
        let operation = Task { try await authenticator.authenticate(reason: "Unlock") }
        defer { operation.cancel() }
        #expect(await waitUntil { context.isPending })

        operation.cancel()
        #expect(context.invalidationCount == 1)
        context.finish(with: .success(true))

        await #expect(throws: CancellationError.self) { try await operation.value }
    }

    @Test("Unavailable or declined authentication remains unsuccessful")
    func preservesUnsuccessfulResult() async throws {
        let context = ControlledBikeLockAuthenticationContext(immediateResult: false)
        let authenticator = LocalAuthenticationBikeLockAuthenticator(makeContext: { context })

        #expect(try await !authenticator.authenticate(reason: "Unlock"))
        #expect(context.invalidationCount == 0)
    }
}
