import DesignSystem
import SwiftUI

struct DashboardCompassDial: View {
    let headingDegrees: Double
    let isHeadingAvailable: Bool
    let cardinalDirectionText: String
    let headingText: String
    let altitudeText: String?
    let reduceMotion: Bool
    @State private var displayedHeadingDegrees = Double.zero

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = side / 2

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignColor.elevatedSurface,
                                DesignColor.groupedSurface.opacity(Constants.ambientEdgeOpacity)
                            ],
                            center: .center,
                            startRadius: .zero,
                            endRadius: radius
                        )
                    )
                    .frame(width: side, height: side)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignColor.critical.opacity(Constants.ringAccentOpacity),
                                DesignColor.border,
                                DesignColor.informational.opacity(Constants.ringAccentOpacity)
                            ],
                            startPoint: .top,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: Constants.ringWidth
                    )
                    .frame(width: side, height: side)

                Circle()
                    .inset(by: Constants.innerRingInset)
                    .stroke(DesignColor.primaryText.opacity(Constants.innerRingOpacity), lineWidth: 1)
                    .frame(width: side, height: side)

                DashboardCompassTicks()
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(-displayedHeadingDegrees))

                ForEach(Constants.cardinals) { cardinal in
                    Text(cardinal.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(
                            cardinal.label == "N"
                                ? DesignColor.critical
                                : DesignColor.secondaryText
                        )
                        .position(
                            point(
                                center: center,
                                radius: radius * Constants.cardinalRadiusRatio,
                                degrees: cardinal.degrees - displayedHeadingDegrees
                            )
                        )
                }

                centerReadout

                headingMarker
                    .offset(y: -radius + Constants.markerInset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .opacity(isHeadingAvailable ? 1 : Constants.unavailableOpacity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            displayedHeadingDegrees = headingDegrees
        }
        .onChange(of: headingDegrees) { _, newValue in
            guard isHeadingAvailable else { return }
            updateDisplayedHeading(to: newValue)
        }
        .onChange(of: isHeadingAvailable) { _, isAvailable in
            guard isAvailable else { return }
            displayedHeadingDegrees = headingDegrees
        }
        .accessibilityHidden(true)
    }

    private var headingMarker: some View {
        ZStack {
            Circle()
                .fill(DesignColor.critical.opacity(Constants.markerGlowOpacity))
                .frame(width: Constants.markerGlowSize, height: Constants.markerGlowSize)
                .blur(radius: Constants.markerGlowRadius)
            Image(systemName: "triangle.fill")
                .font(.system(size: Constants.markerSize, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignColor.critical, DesignColor.warning],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(
                    color: DesignColor.critical.opacity(Constants.markerShadowOpacity),
                    radius: Constants.markerShadowRadius
                )
        }
    }

    private var centerReadout: some View {
        VStack(spacing: Constants.centerSpacing) {
            Text(cardinalDirectionText)
                .font(.system(size: Constants.cardinalFontSize, weight: .medium, design: .rounded))
                .minimumScaleFactor(Constants.minimumTextScale)
                .lineLimit(1)
            Text(headingText)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DesignColor.secondaryText)
            if let altitudeText {
                Label(altitudeText, systemImage: "mountain.2.fill")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignColor.secondaryText)
                    .padding(.top, Constants.altitudeTopPadding)
            }
        }
    }

    private func point(center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let radians = (degrees - Constants.northOffsetDegrees) * .pi / 180
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    private func updateDisplayedHeading(to heading: Double) {
        let target = DashboardCompassRotation.nearestEquivalent(
            to: heading,
            from: displayedHeadingDegrees
        )
        guard !reduceMotion else {
            displayedHeadingDegrees = target
            return
        }
        withAnimation(.snappy(duration: Constants.animationDuration)) {
            displayedHeadingDegrees = target
        }
    }

    private enum Constants {
        static let ringWidth: CGFloat = 1
        static let ringAccentOpacity = 0.45
        static let innerRingInset: CGFloat = 3
        static let innerRingOpacity = 0.06
        static let ambientEdgeOpacity = 0.2
        static let cardinalRadiusRatio: CGFloat = 0.72
        static let markerSize: CGFloat = 9
        static let markerInset: CGFloat = 4
        static let markerGlowSize: CGFloat = 24
        static let markerGlowOpacity = 0.24
        static let markerGlowRadius: CGFloat = 5
        static let markerShadowOpacity = 0.65
        static let markerShadowRadius: CGFloat = 3
        static let cardinalFontSize: CGFloat = 34
        static let centerSpacing: CGFloat = 1
        static let altitudeTopPadding: CGFloat = 4
        static let minimumTextScale: CGFloat = 0.7
        static let unavailableOpacity = 0.45
        static let northOffsetDegrees = 90.0
        static let animationDuration = 0.24
        static let cardinals = [
            Cardinal(label: "N", degrees: 0),
            Cardinal(label: "E", degrees: 90),
            Cardinal(label: "S", degrees: 180),
            Cardinal(label: "W", degrees: 270)
        ]
    }
}

private struct DashboardCompassTicks: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - Constants.inset
            for index in 0 ..< Constants.tickCount {
                let isMajor = index.isMultiple(of: Constants.majorTickInterval)
                let angle = Double(index) * Constants.degreesPerTick - Constants.northOffsetDegrees
                let radians = angle * .pi / 180
                let tickLength = isMajor ? Constants.majorTickLength : Constants.minorTickLength
                var path = Path()
                path.move(to: point(center: center, radius: radius - tickLength, radians: radians))
                path.addLine(to: point(center: center, radius: radius, radians: radians))
                context.stroke(
                    path,
                    with: .color(isMajor ? DesignColor.secondaryText : DesignColor.border),
                    lineWidth: isMajor ? Constants.majorTickWidth : Constants.minorTickWidth
                )
            }
        }
    }

    private func point(center: CGPoint, radius: CGFloat, radians: Double) -> CGPoint {
        CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    private enum Constants {
        static let tickCount = 72
        static let majorTickInterval = 6
        static let degreesPerTick = 5.0
        static let northOffsetDegrees = 90.0
        static let inset: CGFloat = 4
        static let majorTickLength: CGFloat = 9
        static let minorTickLength: CGFloat = 4
        static let majorTickWidth: CGFloat = 1.5
        static let minorTickWidth: CGFloat = 1
    }
}

private struct Cardinal: Identifiable {
    let label: String
    let degrees: Double

    var id: String { label }
}
