import BikeDomain
import Foundation
import SettingsDomain

public struct PowerModeSettingsViewStateMapper: Sendable {
    private let controls: PowerModeControlMapper
    private let statusMapper: PowerModeStatusMapper
    private let selection: PowerModeMapSelectionMapper

    init(
        controls: PowerModeControlMapper, statusMapper: PowerModeStatusMapper, selection: PowerModeMapSelectionMapper
    ) {
        self.controls = controls
        self.statusMapper = statusMapper
        self.selection = selection
    }

    func map(_ input: PowerModeSettingsMappingInput) -> PowerModeSettingsViewState {
        let selection = selectionData(for: input)
        let controls = self.controls.controlData(for: input)
        let operation = statusMapper.operationStatus(
            configuration: controls.configuration,
            isTractionControlReady: controls.isTractionControlReady,
            input: input
        )
        let connectionText = statusMapper.connectionText(input.connection.state)
        let capabilityText = statusMapper.capabilityText(
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
            status: statusMapper.status(
                connectionState: input.connection.state,
                connection: connection,
                operation: operation,
                isActivity: input.isRefreshing
            ),
            canRefresh: input.isStarted
                && statusMapper.isAuthenticated(input.connection.state)
                && !input.isRefreshing
                && !input.isPreparingControl
                && !input.isApplyingControl,
            controlGroups: self.controls.controlGroups(from: controls.adjustments)
        )
    }

    private func selectionData(
        for input: PowerModeSettingsMappingInput
    ) -> PowerModeSelectionData {
        let names = input.settings.powerModeNames(forVIN: input.profile?.vin)
        let maps = selection.map(settings: input.settings, profile: input.profile, selected: input.selectedMapIndex)
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
