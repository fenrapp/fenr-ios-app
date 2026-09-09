import Foundation
import VehicleSession

@MainActor
public enum PowerModeFeatureFactory {
    public static func make(
        vehicleSession: any VehicleSessionService, basicUseCases: PowerModeSettingsUseCases,
        advancedUseCases: PowerModeAdvancedUseCases, locale: Locale, makePresetID: @escaping @Sendable () -> UUID
    ) -> PowerModeFeature {
        let context = PowerModeContext()
        let operations = PowerModeOperationController()
        let names = PowerModeNameCoordinator(context: context, useCases: basicUseCases)
        let presetCompatibility = PowerModePresetCompatibility()
        let mapper = PowerModeAdvancedViewStateMapper(
            calibration: advancedUseCases.calibration, locale: locale, presetCompatibility: presetCompatibility
        )
        let store = PowerModeDraftStore(
            factory: .init(calibration: advancedUseCases.calibration), calibration: advancedUseCases.calibration,
            presetCompatibility: presetCompatibility
        )
        let presets = PowerModePresetCoordinator(useCases: advancedUseCases, makeID: makePresetID)
        let advanced = PowerModeAdvancedOperations(
            context: context, operations: operations, store: store, presets: presets, useCases: advancedUseCases
        )
        let controls = PowerModeBasicControls(
            context: context, operations: operations, advanced: advanced, store: store, useCases: basicUseCases,
            writer: .init(useCases: basicUseCases, advanced: advancedUseCases),
            preparation: .init(useCases: basicUseCases)
        )
        let session = PowerModeSessionCoordinator(
            vehicleSession: vehicleSession, context: context, operations: operations, names: names,
            controls: controls, advanced: advanced, store: store, presets: presets
        )
        return .init(
            basic: PowerModeSettingsViewModel(
                context: context, session: session, controls: controls, operations: operations,
                names: names, store: store, mapper: PowerModeSettingsMapperFactory.make(locale: locale),
                summaryMapper: .init(),
                hasAdvancedEditor: advanced.isAvailable
            ),
            advanced: PowerModeAdvancedViewModel(
                context: context, session: session, store: store, operations: operations,
                advanced: advanced, presets: presets, names: names, mapper: mapper, mapMapper: .init()
            )
        )
    }
}
