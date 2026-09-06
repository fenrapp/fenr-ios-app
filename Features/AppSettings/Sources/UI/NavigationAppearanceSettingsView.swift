#if os(iOS)
import SwiftUI

public struct NavigationAppearanceSettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel

    public init(viewModel: AppSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationAppearanceSettingsContent(
            lineStyles: viewModel.viewState.navigationSettings.lineStyles,
            setColor: { id, color in
                viewModel.setNavigationLineColor(groupID: id, red: color.red, green: color.green, blue: color.blue)
            },
            selectThickness: { viewModel.selectNavigationLineThickness(groupID: $0, thicknessID: $1) }
        )
    }
}
#endif
