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
    @ViewBuilder
    func rideNavigationGlassSurface(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            background(
                .ultraThickMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(Constants.fallbackBorderOpacity))
            }
        }
    }

    @ViewBuilder
    func rideNavigationGlassControl() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Circle())
        } else {
            background(.ultraThickMaterial, in: Circle())
            .overlay {
                Circle().strokeBorder(.white.opacity(Constants.fallbackBorderOpacity))
            }
        }
    }

    @ViewBuilder
    func rideNavigationGlassChip() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Capsule())
        } else {
            background(.ultraThickMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(.white.opacity(Constants.fallbackBorderOpacity))
                }
        }
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

private enum Constants {
    static let fallbackBorderOpacity = 0.12
}
