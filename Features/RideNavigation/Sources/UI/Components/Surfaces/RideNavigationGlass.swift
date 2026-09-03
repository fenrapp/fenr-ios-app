import SwiftUI

struct RideNavigationGlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    func rideNavigationGlassSurface(cornerRadius: CGFloat) -> some View {
        modifier(RideNavigationGlassSurfaceModifier(cornerRadius: cornerRadius))
    }

    func rideNavigationGlassControl() -> some View {
        modifier(RideNavigationGlassControlModifier())
    }

    func rideNavigationGlassChip() -> some View {
        modifier(RideNavigationGlassChipModifier())
    }

    func rideNavigationFocusAppearance(_ isActive: Bool) -> some View {
        environment(\.rideNavigationUsesFocusAppearance, isActive)
    }

    @ViewBuilder
    func rideNavigationPrimaryButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func rideNavigationSecondaryButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

private struct RideNavigationGlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rideNavigationUsesFocusAppearance) private var usesFocusAppearance
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
                .background(
                    .ultraThickMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor.opacity(Constants.fallbackBorderOpacity))
                }
        }
    }

    private var borderColor: Color {
        guard usesFocusAppearance else { return .white }
        return RideNavigationFocusPalette(colorScheme: colorScheme).foreground
    }
}

private struct RideNavigationGlassControlModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rideNavigationUsesFocusAppearance) private var usesFocusAppearance

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.ultraThickMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(borderColor.opacity(Constants.fallbackBorderOpacity))
                }
        }
    }

    private var borderColor: Color {
        guard usesFocusAppearance else { return .white }
        return RideNavigationFocusPalette(colorScheme: colorScheme).foreground
    }
}

private struct RideNavigationGlassChipModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rideNavigationUsesFocusAppearance) private var usesFocusAppearance

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.ultraThickMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(borderColor.opacity(Constants.fallbackBorderOpacity))
                }
        }
    }

    private var borderColor: Color {
        guard usesFocusAppearance else { return .white }
        return RideNavigationFocusPalette(colorScheme: colorScheme).foreground
    }
}

private struct RideNavigationFocusAppearanceKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var rideNavigationUsesFocusAppearance: Bool {
        get { self[RideNavigationFocusAppearanceKey.self] }
        set { self[RideNavigationFocusAppearanceKey.self] = newValue }
    }
}

private enum Constants {
    static let fallbackBorderOpacity = 0.12
}
