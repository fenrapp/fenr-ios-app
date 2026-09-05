import BikeDemo
import Foundation

struct AppExperience {
    let id: UUID
    let root: AppRootDependencies
    let demoViewModel: BikeDemoViewModel?
    let close: @MainActor () async -> Void
    let discard: @MainActor () async throws -> Void
}
