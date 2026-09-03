#if os(iOS)
import SwiftUI

public struct BikeModelSettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel

    public init(viewModel: AppSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            PowerTierSettingsSection(
                state: viewModel.viewState.powerTier,
                onSelectDeclaredTier: viewModel.selectDeclaredPowerTier,
                onVerify: viewModel.verifyPowerTierWithBike
            )
        }
        .navigationTitle(Text(.appSettingsBikeModelTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
