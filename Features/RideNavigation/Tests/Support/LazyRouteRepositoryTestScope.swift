import RideNavigationDomain

@MainActor
enum LazyRouteRepositoryTestScope {
    static func run(
        summaries: [RideRouteSummary],
        operation: @MainActor (LazyRecordedRouteRepository) async throws -> Void
    ) async throws {
        let repository = LazyRecordedRouteRepository(summaries: summaries)
        do {
            try await operation(repository)
            await repository.close()
        } catch {
            await repository.close()
            throw error
        }
    }
}
