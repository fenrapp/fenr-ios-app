import SwiftUI

public struct ChargingSettingsView: View {
    private let viewModel: ChargingSettingsViewModel

    public init(viewModel: ChargingSettingsViewModel) { self.viewModel = viewModel }

    public var body: some View {
        let state = viewModel.viewState
        Form {
            Section {
                Picker(.chargingSettingsCharger, selection: Binding(
                    get: { state.selectedChargerID }, set: { viewModel.selectCharger(id: $0) }
                )) {
                    Text(.chargingSettingsChooseCharger).tag("")
                    Text(.chargingSettingsStandard).tag("0")
                    Text(.chargingSettingsFast).tag("2")
                    Text(.chargingSettingsBackpack).tag("3")
                }
                .disabled(!state.canSelectCharger)
                .accessibilityIdentifier("chargingSettings.charger")
                ChargingSettingsSlider(
                    title: .chargingSettingsPower, value: state.power,
                    range: Constants.minimumPower ... state.maximumPower,
                    step: Constants.powerStep, detail: state.powerDetail,
                    isEnabled: state.canEditPower, isPower: true, commit: viewModel.setPower
                )
                .accessibilityIdentifier("chargingSettings.power")
                ChargingSettingsSlider(
                    title: .chargingSettingsTarget, value: state.target,
                    range: Constants.targetRange, step: Constants.targetStep,
                    detail: state.targetDetail, isEnabled: state.canEditTarget,
                    isPower: false, commit: viewModel.setTarget
                )
                .accessibilityIdentifier("chargingSettings.target")
            } footer: {
                Text(.chargingSettingsControlsFooter)
            }
            Section {
                HStack {
                    if state.isBusy { ProgressView() }
                    Text(verbatim: state.status)
                }
                if state.canRetry {
                    Button(.chargingSettingsRetry, action: viewModel.retry)
                }
                if state.hasPendingChanges {
                    Button(.chargingSettingsCancel, role: .destructive, action: viewModel.cancelPending)
                }
            } footer: {
                Text(.chargingSettingsConnectionFooter)
            }
        }
        .navigationTitle(Text(.chargingSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private enum Constants {
        static let minimumPower: Double = 300
        static let powerStep: Double = 100
        static let targetRange: ClosedRange<Double> = 1 ... 100
        static let targetStep: Double = 1
    }
}
