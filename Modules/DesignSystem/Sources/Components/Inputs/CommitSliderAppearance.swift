import SwiftUI

public struct CommitSliderAppearance {
    public let gradientStops: [Gradient.Stop]
    public let thumbColor: Color
    public let showsCenterMarker: Bool
    public let providesCommitFeedback: Bool

    public init(
        gradientStops: [Gradient.Stop],
        thumbColor: Color = .white,
        showsCenterMarker: Bool = false,
        providesCommitFeedback: Bool = true
    ) {
        self.gradientStops = gradientStops
        self.thumbColor = thumbColor
        self.showsCenterMarker = showsCenterMarker
        self.providesCommitFeedback = providesCommitFeedback
    }
}

#Preview("Gradient commit slider") {
    CommitSlider(
        value: 35,
        in: 0 ... 100,
        step: 5,
        appearance: CommitSliderAppearance(
            gradientStops: [
                .init(color: .yellow, location: .zero),
                .init(color: .orange, location: 1)
            ]
        ),
        accessibilityLabel: "Regenerative braking",
        accessibilityValue: { "\($0.formatted()) percent" },
        onCommit: { _ in },
        header: { value in
            Text(verbatim: "Regenerative braking \(value.formatted())%")
        },
        footer: {
            Text(verbatim: "0% - 100%")
                .font(.caption)
        }
    )
    .padding()
}
