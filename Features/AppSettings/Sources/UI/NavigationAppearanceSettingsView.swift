#if os(iOS)
import SwiftUI
import UIKit

public struct NavigationAppearanceSettingsView: View {
    @ObservedObject private var viewModel: AppSettingsViewModel

    public init(viewModel: AppSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            ForEach(viewModel.viewState.navigationSettings.lineStyles) { style in
                Section {
                    ColorPicker(
                        .appSettingsNavigationColor,
                        selection: colorBinding(for: style),
                        supportsOpacity: false
                    )
                    Picker(
                        .appSettingsNavigationThickness,
                        selection: thicknessBinding(for: style)
                    ) {
                        ForEach(style.thickness.options) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(style.title)
                }
            }
        }
        .navigationTitle(Text(.appSettingsNavigationAppearanceTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorBinding(for style: NavigationLineStyleViewData) -> Binding<Color> {
        Binding(
            get: {
                Color(
                    .sRGB,
                    red: style.color.red,
                    green: style.color.green,
                    blue: style.color.blue,
                    opacity: 1
                )
            },
            set: { color in
                guard let components = color.sRGBComponents else { return }
                viewModel.setNavigationLineColor(
                    groupID: style.id,
                    red: components.red,
                    green: components.green,
                    blue: components.blue
                )
            }
        )
    }

    private func thicknessBinding(for style: NavigationLineStyleViewData) -> Binding<String> {
        Binding(
            get: { style.thickness.selectedID },
            set: {
                viewModel.selectNavigationLineThickness(
                    groupID: style.id,
                    thicknessID: $0
                )
            }
        )
    }
}

private extension Color {
    var sRGBComponents: NavigationColorComponents? {
        let color = UIColor(self)
        var red: CGFloat = .zero
        var green: CGFloat = .zero
        var blue: CGFloat = .zero
        var alpha: CGFloat = .zero
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return NavigationColorComponents(
            red: Double(red),
            green: Double(green),
            blue: Double(blue)
        )
    }
}
#endif
