import BikeDomain
import Foundation
import SettingsDomain

public struct PowerModeSettingsViewStateMapper: Sendable {
    let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    func map(_ input: PowerModeSettingsMappingInput) -> PowerModeSettingsViewState {
        let selection = selectionData(for: input)
        let controls = controlData(for: input)
        let operation = operationStatus(
            configuration: controls.configuration,
            isTractionControlReady: controls.isTractionControlReady,
            input: input
        )
        let connectionText = connectionText(input.connection.state)
        let capabilityText = capabilityText(
            detectedTier: input.telemetry.detectedPowerTier,
            declaredTier: input.profile?.declaredPowerTier
        )
        return makeViewState(
            input: input,
            selection: selection,
            controls: controls,
            operation: operation,
            connection: .init(title: connectionText, capability: capabilityText)
        )
    }

    private func makeViewState(
        input: PowerModeSettingsMappingInput,
        selection: PowerModeSelectionData,
        controls: PowerModeControlData,
        operation: PowerModeOperationStatus,
        connection: PowerModeConnectionPresentation
    ) -> PowerModeSettingsViewState {
        .init(
            maps: selection.maps,
            selectedMapIndex: input.selectedMapIndex,
            currentName: selection.currentName,
            maximumNameLength: PowerModeName.maximumLength,
            canEditName: input.profile?.vin == input.settings.vin && input.profile != nil,
            nameError: input.nameError,
            isSavingName: input.isSavingName,
            nameSaveCompletionID: input.nameSaveCompletionID,
            connectionText: connection.title,
            capabilityText: connection.capability,
            statusText: operation.text,
            statusIsError: operation.isError,
            status: status(
                connectionState: input.connection.state,
                connection: connection,
                operation: operation,
                isActivity: input.isRefreshing
            ),
            canRefresh: input.isStarted
                && isAuthenticated(input.connection.state)
                && !input.isRefreshing
                && !input.isPreparingControl
                && !input.isApplyingControl,
            controlGroups: controlGroups(from: controls.adjustments)
        )
    }

    private func selectionData(
        for input: PowerModeSettingsMappingInput
    ) -> PowerModeSelectionData {
        let names = input.settings.powerModeNames(forVIN: input.profile?.vin)
        let maps = (0 ... 4).map { mapIndex in
            let mapNumber = mapIndex + 1
            let name = names[mapIndex]?.value
            return PowerModeMapViewData(
                id: mapIndex,
                title: name ?? String(mapNumber),
                accessibilityLabel: name.map {
                    String(localized: .powerModeSettingsNamedMapAccessibility(mapNumber, $0))
                } ?? String(localized: .powerModeSettingsMapAccessibility(mapNumber)),
                isSelected: mapIndex == input.selectedMapIndex
            )
        }
        return .init(
            maps: maps,
            currentName: names[input.selectedMapIndex]?.value ?? ""
        )
    }
}

private struct PowerModeSelectionData {
    let maps: [PowerModeMapViewData]
    let currentName: String
}

struct PowerModeConnectionPresentation {
    let title: String
    let capability: String
}
