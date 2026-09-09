import Foundation

struct PowerModeControlPreparation: Sendable {
    struct Result: Sendable {
        let baseReady: Bool
        let tractionReady: Bool
        let error: String?
    }
    let useCases: PowerModeSettingsUseCases

    func execute(map: Int, tractionAvailable: Bool) async throws -> Result {
        do { try await useCases.preparePowerModeControl.execute(mapIndex: map) } catch {
            try Task.checkCancellation()
            return .init(baseReady: false, tractionReady: false, error: String(
                localized: .powerModeSettingsBaseControlsUnavailableError
            ))
        }
        try Task.checkCancellation()
        guard tractionAvailable else { return .init(baseReady: true, tractionReady: false, error: nil) }
        do { try await useCases.prepareTractionControl.execute(mapIndex: map) } catch {
            try Task.checkCancellation()
            return .init(baseReady: true, tractionReady: false, error: String(
                localized: .powerModeSettingsTractionControlsUnavailableError
            ))
        }
        return .init(baseReady: true, tractionReady: true, error: nil)
    }
}
