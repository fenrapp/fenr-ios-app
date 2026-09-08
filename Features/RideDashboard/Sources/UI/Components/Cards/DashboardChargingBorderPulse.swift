import SwiftUI

struct DashboardChargingBorderPulse: View {
    let path: Path
    let progress: Double
    let isExpanded: Bool
    let palette: DashboardChargingBorderPalette

    var body: some View {
        let colors = palette.balancing
        let start = Color(colors.start)
        let glowOpacity = isExpanded ? Constants.maximumGlowOpacity : Constants.minimumGlowOpacity
        path
            .trim(from: .zero, to: progress)
            .stroke(
                AngularGradient(colors: [start, Color(colors.middle), start], center: .center),
                style: StrokeStyle(lineWidth: Constants.borderWidth, lineCap: .round, lineJoin: .round)
            )
            .opacity(isExpanded ? palette.pulseMaximumOpacity : Constants.minimumOpacity)
            .scaleEffect(isExpanded ? Constants.maximumScale : 1)
            .shadow(
                color: Color(colors.glow).opacity(glowOpacity),
                radius: isExpanded ? Constants.maximumGlowRadius : Constants.minimumGlowRadius
            )
    }

    private enum Constants {
        static let borderWidth: CGFloat = 6
        static let maximumScale = 1.006
        static let minimumOpacity = 0.08
        static let minimumGlowOpacity = 0.1
        static let maximumGlowOpacity = 0.56
        static let minimumGlowRadius: CGFloat = 2
        static let maximumGlowRadius: CGFloat = 13
    }
}
