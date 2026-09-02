import DesignSystem
import SwiftUI

struct DashboardAmbientLighting: View {
    @Environment(\.colorScheme) private var colorScheme
    let indicators: [DashboardIndicatorViewData]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if isActive(.leftTurn) {
                    halfScreenLighting(
                        side: .leading,
                        availableWidth: proxy.size.width
                    )
                }

                if isActive(.rightTurn) {
                    halfScreenLighting(
                        side: .trailing,
                        availableWidth: proxy.size.width
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(Constants.screenInset)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(.rideDashboardIndicatorsActiveAccessibility)
        .accessibilityValue(accessibilityValue)
        .accessibilityHidden(accessibilityValue.isEmpty)
        .animation(Constants.stateAnimation, value: indicators)
    }

    private func halfScreenLighting(
        side: Side,
        availableWidth: CGFloat
    ) -> some View {
        HStack(spacing: .zero) {
            if side == .trailing {
                Spacer(minLength: .zero)
            }

            ambientFill(
                opacity: turnSignalOpacity,
                side: side
            )
            .frame(width: availableWidth / 2)

            if side == .leading {
                Spacer(minLength: .zero)
            }
        }
    }

    @ViewBuilder
    private func ambientFill(
        opacity: Double,
        side: Side
    ) -> some View {
        if #available(iOS 26.0, *) {
            switch side {
            case .leading:
                ConcentricRectangle(
                    uniformLeadingCorners: .concentric,
                    uniformTrailingCorners: .fixed(.zero)
                )
                .fill(DesignColor.warning.opacity(opacity))
            case .trailing:
                ConcentricRectangle(
                    uniformLeadingCorners: .fixed(.zero),
                    uniformTrailingCorners: .concentric
                )
                .fill(DesignColor.warning.opacity(opacity))
            }
        } else {
            RoundedRectangle(cornerRadius: Constants.fallbackCornerRadius, style: .continuous)
                .fill(DesignColor.warning.opacity(opacity))
        }
    }

    private var turnSignalOpacity: Double {
        colorScheme == .dark
            ? Constants.darkTurnSignalOpacity
            : Constants.lightTurnSignalOpacity
    }

    private var accessibilityValue: String {
        indicators
            .filter { $0.isActive && IndicatorID(rawValue: $0.id) != nil }
            .map(\.accessibilityLabel)
            .joined(separator: ", ")
    }

    private func isActive(_ id: IndicatorID) -> Bool {
        indicators.contains { $0.id == id.rawValue && $0.isActive }
    }

    private enum IndicatorID: String {
        case leftTurn
        case rightTurn
    }

    private enum Side {
        case leading
        case trailing
    }

    private enum Constants {
        static let screenInset: CGFloat = 4
        static let fallbackCornerRadius: CGFloat = 28
        static let darkTurnSignalOpacity = 0.16
        static let lightTurnSignalOpacity = 0.11
        static let stateAnimation = Animation.easeInOut(duration: 0.12)
    }
}
