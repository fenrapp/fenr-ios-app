import Foundation

struct PowerModeControlPreparation: Sendable {
    struct Result: Sendable {
        let baseReady: Bool
        let error: String?
    }
    let useCases: PowerModeSettingsUseCases

    func execute(map: Int) async throws -> Result {
        do { try await useCases.preparePowerModeControl.execute(mapIndex: map) } catch {
            try Task.checkCancellation()
            return .init(baseReady: false, error: String(localized: .powerModeSettingsBaseControlsUnavailableError))
        }
        try Task.checkCancellation()
        return .init(baseReady: true, error: nil)
    }
}
