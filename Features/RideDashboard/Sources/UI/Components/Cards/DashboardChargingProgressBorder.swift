import DesignSystem
import SwiftUI

struct DashboardChargingProgressBorder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var balancingPulse = false

    let progress: Double?
    let cornerRadius: CGFloat
    let isBalancing: Bool

    var body: some View {
        ZStack {
            cardShape
                .stroke(DesignColor.border, lineWidth: Constants.borderWidth)

            if progress != nil {
                if isBalancing {
                    cardShape
                        .trim(from: .zero, to: clampedProgress)
                        .stroke(chargingGradient, style: balancingPulseStrokeStyle)
                        .opacity(balancingPulseOpacity)
                        .scaleEffect(balancingPulse ? Constants.balancingPulseScale : 1)
                        .shadow(
                            color: progressGlowColor.opacity(balancingPulseGlowOpacity),
                            radius: balancingPulseGlowRadius
                        )
                }

                cardShape
                    .trim(from: .zero, to: clampedProgress)
                    .stroke(chargingGradient, style: progressStrokeStyle)
                    .shadow(
                        color: progressGlowColor.opacity(progressGlowOpacity),
                        radius: Constants.progressGlowRadius
                    )

                cardShape
                    .trim(from: progressHeadStart, to: clampedProgress)
                    .stroke(progressHeadColor, style: progressHeadStrokeStyle)
                    .shadow(
                        color: progressHeadColor.opacity(Constants.progressHeadGlowOpacity),
                        radius: Constants.progressHeadGlowRadius
                    )
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Constants.progressAnimationDuration),
            value: clampedProgress
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Constants.stateAnimationDuration),
            value: isBalancing
        )
        .onAppear(perform: updateBalancingPulse)
        .onChange(of: isBalancing) { updateBalancingPulse() }
        .onChange(of: reduceMotion) { updateBalancingPulse() }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var clampedProgress: Double {
        min(max(progress ?? .zero, .zero), 1)
    }

    private var progressHeadStart: Double {
        max(clampedProgress - Constants.progressHeadLength, .zero)
    }

    private var chargingGradient: AngularGradient {
        AngularGradient(colors: progressGradientColors, center: .center)
    }

    private var progressGradientColors: [Color] {
        if isBalancing {
            return balancingGradientColors
        }

        return switch colorScheme {
        case .dark:
            [DesignColor.informational, DesignColor.positive, DesignColor.informational]
        case .light:
            [Constants.lightInformational, Constants.lightPositive, Constants.lightInformational]
        @unknown default:
            [DesignColor.informational, DesignColor.positive, DesignColor.informational]
        }
    }

    private var balancingGradientColors: [Color] {
        return switch colorScheme {
        case .dark:
            [Color.cyan, Color.indigo, Color.cyan]
        case .light:
            [
                DashboardSemanticColor.lightBalancing,
                Constants.lightBalancingMiddle,
                DashboardSemanticColor.lightBalancing
            ]
        @unknown default:
            [Color.cyan, Color.indigo, Color.cyan]
        }
    }

    private var progressHeadColor: Color {
        if isBalancing {
            return colorScheme == .dark ? Color.cyan : DashboardSemanticColor.lightBalancing
        }
        return colorScheme == .dark ? Color.mint : Constants.lightPositive
    }

    private var progressGlowColor: Color {
        isBalancing ? progressHeadColor : DesignColor.informational
    }

    private var progressGlowOpacity: Double {
        colorScheme == .dark ? Constants.darkProgressGlowOpacity : Constants.lightProgressGlowOpacity
    }

    private var balancingPulseOpacity: Double {
        balancingPulse ? balancingPulseMaximumOpacity : Constants.balancingPulseMinimumOpacity
    }

    private var balancingPulseMaximumOpacity: Double {
        colorScheme == .dark
            ? Constants.darkBalancingPulseMaximumOpacity
            : Constants.lightBalancingPulseMaximumOpacity
    }

    private var balancingPulseGlowOpacity: Double {
        balancingPulse
            ? Constants.balancingPulseMaximumGlowOpacity
            : Constants.balancingPulseMinimumGlowOpacity
    }

    private var balancingPulseGlowRadius: CGFloat {
        balancingPulse ? Constants.balancingPulseMaximumGlowRadius : Constants.balancingPulseMinimumGlowRadius
    }

    private var progressStrokeStyle: StrokeStyle {
        .init(
            lineWidth: Constants.progressBorderWidth,
            lineCap: .round,
            lineJoin: .round
        )
    }

    private var progressHeadStrokeStyle: StrokeStyle {
        .init(
            lineWidth: Constants.progressHeadWidth,
            lineCap: .round,
            lineJoin: .round
        )
    }

    private var balancingPulseStrokeStyle: StrokeStyle {
        .init(
            lineWidth: Constants.balancingPulseBorderWidth,
            lineCap: .round,
            lineJoin: .round
        )
    }

    private func updateBalancingPulse() {
        guard isBalancing, !reduceMotion else {
            balancingPulse = false
            return
        }

        balancingPulse = false
        withAnimation(
            .easeInOut(duration: Constants.balancingPulseDuration)
                .repeatForever(autoreverses: true)
        ) {
            balancingPulse = true
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private enum Constants {
        static let borderWidth: CGFloat = 1
        static let progressBorderWidth: CGFloat = 3
        static let progressGlowRadius: CGFloat = 6
        static let progressHeadWidth: CGFloat = 3.5
        static let progressHeadLength = 0.018
        static let progressHeadGlowRadius: CGFloat = 8
        static let progressHeadGlowOpacity = 0.72
        static let balancingPulseBorderWidth: CGFloat = 6
        static let balancingPulseScale = 1.006
        static let balancingPulseMinimumOpacity = 0.08
        static let darkBalancingPulseMaximumOpacity = 0.46
        static let lightBalancingPulseMaximumOpacity = 0.3
        static let balancingPulseMinimumGlowOpacity = 0.1
        static let balancingPulseMaximumGlowOpacity = 0.56
        static let balancingPulseMinimumGlowRadius: CGFloat = 2
        static let balancingPulseMaximumGlowRadius: CGFloat = 13
        static let darkProgressGlowOpacity = 0.46
        static let lightProgressGlowOpacity = 0.2
        static let progressAnimationDuration = 0.45
        static let stateAnimationDuration = 0.3
        static let balancingPulseDuration = 1.15
        static let lightInformational = Color(red: 0, green: 0.64, blue: 0.68)
        static let lightPositive = Color(red: 0.1, green: 0.7, blue: 0.3)
        static let lightBalancingMiddle = Color(red: 0.26, green: 0.56, blue: 0.96)
    }
}
