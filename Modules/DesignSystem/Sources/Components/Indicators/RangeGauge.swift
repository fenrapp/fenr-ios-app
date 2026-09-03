import SwiftUI

public struct RangeGauge: View {
    private let valueRange: ClosedRange<Double>
    private let average: Double
    private let domain: ClosedRange<Double>
    private let trackColor: Color
    private let gradientStops: [Gradient.Stop]?
    private let markerColor: Color

    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var rangeHeight: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var averageMarkerSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var minimumRangeWidth: CGFloat = 4

    public init(
        valueRange: ClosedRange<Double>,
        average: Double,
        domain: ClosedRange<Double>,
        trackColor: Color = DesignColor.inactive,
        gradientStops: [Gradient.Stop]? = nil,
        markerColor: Color = DesignColor.primaryText,
        trackHeight: CGFloat = 14,
        rangeHeight: CGFloat = 8,
        averageMarkerSize: CGFloat = 14,
        minimumRangeWidth: CGFloat = 4
    ) {
        self.valueRange = valueRange
        self.average = average
        self.domain = domain
        self.trackColor = trackColor
        self.gradientStops = gradientStops
        self.markerColor = markerColor
        _trackHeight = ScaledMetric(wrappedValue: trackHeight, relativeTo: .body)
        _rangeHeight = ScaledMetric(wrappedValue: rangeHeight, relativeTo: .body)
        _averageMarkerSize = ScaledMetric(wrappedValue: averageMarkerSize, relativeTo: .body)
        _minimumRangeWidth = ScaledMetric(wrappedValue: minimumRangeWidth, relativeTo: .body)
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = RangeGaugeLayout(domain: domain, width: proxy.size.width)
            ZStack(alignment: .leading) {
                track
                Capsule()
                    .fill(markerColor.opacity(Constants.rangeOpacity))
                    .frame(
                        width: max(
                            layout.position(valueRange.upperBound) - layout.position(valueRange.lowerBound),
                            minimumRangeWidth
                        ),
                        height: rangeHeight
                    )
                    .offset(x: layout.position(valueRange.lowerBound))
                Circle()
                    .fill(markerColor)
                    .frame(width: averageMarkerSize, height: averageMarkerSize)
                    .offset(x: layout.position(average) - averageMarkerSize / 2)
            }
        }
        .frame(height: trackHeight)
        .accessibilityHidden(true)
    }

    private var track: some View {
        Capsule()
            .fill(trackColor)
            .overlay {
                if let gradientStops, !gradientStops.isEmpty {
                    LinearGradient(stops: gradientStops, startPoint: .leading, endPoint: .trailing)
                        .clipShape(Capsule())
                }
            }
    }

    private enum Constants {
        static let rangeOpacity = 0.7
    }
}

struct RangeGaugeLayout {
    let domain: ClosedRange<Double>
    let width: CGFloat

    func position(_ value: Double) -> CGFloat {
        guard domain.lowerBound != domain.upperBound else { return .zero }
        let clampedValue = min(max(value, domain.lowerBound), domain.upperBound)
        return (clampedValue - domain.lowerBound)
            / (domain.upperBound - domain.lowerBound)
            * width
    }
}

#Preview("Range gauge") {
    RangeGauge(
        valueRange: 22 ... 41,
        average: 31,
        domain: -10 ... 100,
        gradientStops: [
            .init(color: DesignColor.warning, location: .zero),
            .init(color: DesignColor.positive, location: 0.5),
            .init(color: DesignColor.critical, location: 1)
        ]
    )
    .padding()
}
