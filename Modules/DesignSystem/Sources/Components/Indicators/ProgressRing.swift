import SwiftUI

public struct ProgressRing<Content: View>: View {
    private let progress: Double
    private let color: Color
    private let trackColor: Color
    private let content: Content

    @ScaledMetric(relativeTo: .body) private var lineWidth: CGFloat = 10

    public init(
        progress: Double,
        color: Color,
        trackColor: Color = DesignColor.inactive,
        lineWidth: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.color = color
        self.trackColor = trackColor
        self.content = content()
        _lineWidth = ScaledMetric(wrappedValue: lineWidth, relativeTo: .body)
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: .zero, to: ProgressRingLayout.clamped(progress))
                .stroke(
                    color.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            content
        }
    }
}

enum ProgressRingLayout {
    static func clamped(_ progress: Double) -> Double {
        min(max(progress, .zero), 1)
    }
}

#Preview("Progress ring") {
    ProgressRing(progress: 0.86, color: DesignColor.positive) {
        Text(verbatim: "86%")
            .font(.title.bold())
    }
    .frame(width: 180, height: 180)
    .padding()
}
