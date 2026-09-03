import SwiftUI

public struct SegmentedDistributionBar: View {
    public struct Segment {
        public let value: Double
        public let color: Color

        public init(value: Double, color: Color) {
            self.value = value
            self.color = color
        }
    }

    private let segments: [Segment]

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var segmentSpacing: CGFloat = 2
    @ScaledMetric(relativeTo: .body) private var minimumSegmentWidth: CGFloat = 4

    public init(
        segments: [Segment],
        height: CGFloat = 10,
        segmentSpacing: CGFloat = 2,
        minimumSegmentWidth: CGFloat = 4
    ) {
        self.segments = segments
        _height = ScaledMetric(wrappedValue: height, relativeTo: .body)
        _segmentSpacing = ScaledMetric(wrappedValue: segmentSpacing, relativeTo: .body)
        _minimumSegmentWidth = ScaledMetric(wrappedValue: minimumSegmentWidth, relativeTo: .body)
    }

    public var body: some View {
        GeometryReader { proxy in
            let populatedSegments = segments.filter { $0.value > .zero }
            let widths = SegmentedDistributionLayout.widths(
                values: populatedSegments.map(\.value),
                totalWidth: proxy.size.width,
                spacing: segmentSpacing,
                minimumWidth: minimumSegmentWidth
            )

            HStack(spacing: segmentSpacing) {
                ForEach(Array(populatedSegments.enumerated()), id: \.offset) { index, segment in
                    segment.color
                        .frame(width: widths[index])
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
    }
}

enum SegmentedDistributionLayout {
    static func widths(
        values: [Double],
        totalWidth: CGFloat,
        spacing: CGFloat,
        minimumWidth: CGFloat
    ) -> [CGFloat] {
        let positiveValues = values.map { max($0, .zero) }
        let valueTotal = positiveValues.reduce(.zero, +)
        guard valueTotal > .zero, !values.isEmpty else {
            return Array(repeating: .zero, count: values.count)
        }

        let spacingWidth = CGFloat(max(.zero, values.count - 1)) * max(spacing, .zero)
        let availableWidth = max(totalWidth - spacingWidth, .zero)
        let fittedMinimum = min(max(minimumWidth, .zero), availableWidth / CGFloat(values.count))
        var widths = Array(repeating: CGFloat.zero, count: values.count)
        var remainingIndices = Array(values.indices)
        var remainingWidth = availableWidth
        var remainingValue = valueTotal

        while let constrainedIndex = remainingIndices.first(where: { index in
            remainingWidth * positiveValues[index] / remainingValue < fittedMinimum
        }) {
            widths[constrainedIndex] = fittedMinimum
            remainingWidth -= fittedMinimum
            remainingValue -= positiveValues[constrainedIndex]
            remainingIndices.removeAll { $0 == constrainedIndex }
            guard remainingValue > .zero else { break }
        }

        guard remainingValue > .zero else { return widths }
        for index in remainingIndices {
            widths[index] = remainingWidth * positiveValues[index] / remainingValue
        }
        return widths
    }
}

#Preview("Segmented distribution bar") {
    SegmentedDistributionBar(
        segments: [
            .init(value: 20, color: DesignColor.positive),
            .init(value: 3, color: DesignColor.warning),
            .init(value: 1, color: DesignColor.critical)
        ]
    )
    .padding()
}
