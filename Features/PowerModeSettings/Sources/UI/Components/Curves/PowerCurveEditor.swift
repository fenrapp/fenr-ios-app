import Charts
import DesignSystem
import SwiftUI

struct PowerCurveEditor: View {
    let points: [PowerCurvePointViewData]
    let samples: [PowerCurvePointViewData]
    let kind: PowerModeCurveKind
    let unit: String
    let summary: String
    let isEnabled: Bool
    let commit: (Int, Double) -> Void
    let chartHeight: CGFloat
    var showsHeader = true
    @State private var selectedIndex: Int?
    @State private var draggedValue: Double?
    @State private var editingPoint: PowerCurvePointViewData?

    private var selected: PowerCurvePointViewData? {
        points.first { $0.id == selectedIndex } ?? (points.isEmpty ? nil : points[points.count / 2])
    }

    private var accent: Color { kind == .power ? DesignColor.warning : DesignColor.informational }
    private var ceiling: Double { max(samples.map(\.maximum).max() ?? 1, 1) }

    private var yTicks: [Double] { Array(stride(from: 0.0, through: ceiling, by: ceiling / Constants.yIntervals)) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.large) {
            if showsHeader { header }
            chart
        }
        .padding(.bottom, DesignSpace.small)
        .onChange(of: isEnabled) {
            draggedValue = nil
            if !isEnabled { editingPoint = nil }
        }
        .sheet(item: $editingPoint) { point in
            PowerCurveValueInput(point: point, unit: unit) { value in
                guard isEnabled else { return }
                commit(point.id, value)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .zero) {
            HStack(alignment: .firstTextBaseline) {
                Text(kind == .power ? .powerCurvePeakLabel : .powerCurveMaximumLabel)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: DesignSpace.extraSmall)
                Text(verbatim: summary)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
            .padding(.vertical, DesignSpace.large)
            HStack(spacing: DesignSpace.medium) {
                Label {
                    Text(.powerCurveSetting)
                } icon: {
                    Capsule().fill(accent).frame(width: Constants.legendWidth, height: Constants.lineWidth)
                }
                Label {
                    Text(.powerCurveLimit)
                } icon: {
                    Capsule().fill(DesignColor.secondaryText)
                        .frame(width: Constants.legendWidth, height: Constants.referenceWidth)
                }
                .foregroundStyle(DesignColor.secondaryText)
            }
            .font(.caption2)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(samples) { sample in
                AreaMark(x: .value(Constants.rpmKey, sample.rpm), y: .value(unit, sample.value))
                    .foregroundStyle(LinearGradient(
                        colors: [accent.opacity(Constants.fillOpacity), accent.opacity(Constants.fadeOpacity)],
                        startPoint: .top, endPoint: .bottom
                    ))
                LineMark(
                    x: .value(Constants.rpmKey, sample.rpm), y: .value(unit, sample.maximum),
                    series: .value(Constants.seriesKey, Constants.limitSeries)
                )
                .foregroundStyle(DesignColor.secondaryText.opacity(Constants.referenceOpacity))
                .lineStyle(StrokeStyle(lineWidth: Constants.referenceWidth))
                LineMark(
                    x: .value(Constants.rpmKey, sample.rpm), y: .value(unit, sample.value),
                    series: .value(Constants.seriesKey, Constants.curveSeries)
                )
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: Constants.lineWidth, lineCap: .round, lineJoin: .round))
            }
            if let selected {
                RuleMark(x: .value(Constants.rpmKey, selected.rpm))
                    .foregroundStyle(accent.opacity(Constants.guideOpacity))
                    .lineStyle(StrokeStyle(lineWidth: Constants.referenceWidth, dash: Constants.dash))
                RuleMark(y: .value(unit, draggedValue ?? selected.value))
                    .foregroundStyle(accent.opacity(Constants.guideOpacity))
                    .lineStyle(StrokeStyle(lineWidth: Constants.referenceWidth, dash: Constants.dash))
            }
            ForEach(points) { point in
                PointMark(
                    x: .value(Constants.rpmKey, point.rpm),
                    y: .value(unit, selected?.id == point.id ? draggedValue ?? point.value : point.value)
                )
                .foregroundStyle(accent)
                .symbol {
                    Circle()
                        .fill(.background)
                        .overlay(Circle().strokeBorder(accent, lineWidth: Constants.pointBorder))
                        .frame(
                            width: selected?.id == point.id ? Constants.selectedSize : Constants.pointSize,
                            height: selected?.id == point.id ? Constants.selectedSize : Constants.pointSize
                        )
                }
                .annotation(
                    position: .top, spacing: DesignSpace.extraSmall,
                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                ) {
                    if selected?.id == point.id {
                        HStack(spacing: DesignSpace.extraExtraSmall) {
                            Text(
                                draggedValue ?? point.value,
                                format: .number.precision(.fractionLength(0 ... (kind == .power ? 1 : 0)))
                            )
                            Text(verbatim: unit)
                        }
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(DesignSpace.extraSmall)
                        .foregroundStyle(DesignColor.primaryText)
                        .background(.background, in: RoundedRectangle(cornerRadius: DesignRadius.small))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignRadius.small)
                                .strokeBorder(DesignColor.border, lineWidth: Constants.referenceWidth)
                        }
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: Constants.rpmRange, range: .plotDimension(padding: DesignSpace.extraSmall))
        .chartYScale(domain: 0 ... ceiling, range: .plotDimension(padding: DesignSpace.small))
        .chartXAxis {
            AxisMarks(values: Constants.rpmTicks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: Constants.gridWidth))
                    .foregroundStyle(DesignColor.border)
                AxisValueLabel(centered: false, anchor: .top, collisionResolution: .disabled) {
                    if let rpm = value.as(Double.self) {
                        Text(rpm / Constants.rpmDivisor, format: .number.precision(.fractionLength(0)))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: Constants.gridWidth))
                    .foregroundStyle(DesignColor.border)
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0)))
            }
        }
        .chartXAxisLabel(.powerCurveAxisThousands, alignment: .trailing)
        .frame(height: chartHeight)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let plotFrame = proxy.plotFrame else { return }
                            updateDrag(value, proxy: proxy, frame: geometry[plotFrame])
                        }
                        .onEnded { _ in
                            if isEnabled, let selected, let draggedValue { commit(selected.id, draggedValue) }
                            draggedValue = nil
                        }
                    )
                    .simultaneousGesture(SpatialTapGesture(count: Constants.editTapCount).onEnded { value in
                        guard let plotFrame = proxy.plotFrame else { return }
                        openValueInput(at: value.location, proxy: proxy, frame: geometry[plotFrame])
                    })
            }
        }
        .accessibilityLabel(.powerCurveChartAccessibility)
        .accessibilityChildren {
            ForEach(points) { point in
                Button(.powerCurvePointAccessibility(point.rpmText)) { selectedIndex = point.id }
                    .accessibilityAction(named: Text(.powerCurveExactValue)) {
                        guard isEnabled else { return }
                        editingPoint = point
                    }
            }
        }
    }

    private func openValueInput(at location: CGPoint, proxy: ChartProxy, frame: CGRect) {
        guard isEnabled else { return }
        let candidates = points.compactMap { point -> (PowerCurvePointViewData, CGFloat)? in
            guard let position = proxy.position(for: (x: point.rpm, y: point.value)) else { return nil }
            let distance = hypot(location.x - frame.minX - position.x, location.y - frame.minY - position.y)
            return (point, distance)
        }
        guard let nearest = candidates.min(by: { $0.1 < $1.1 }), nearest.1 <= Constants.pointHitRadius else { return }
        selectedIndex = nearest.0.id
        draggedValue = nil
        editingPoint = nearest.0
    }

    private func updateDrag(_ value: DragGesture.Value, proxy: ChartProxy, frame: CGRect) {
        guard let rpm: Double = proxy.value(atX: value.startLocation.x - frame.minX),
              let point = points.min(by: { abs($0.rpm - rpm) < abs($1.rpm - rpm) }) else { return }
        selectedIndex = point.id
        guard isEnabled, abs(value.translation.height) > Constants.dragThreshold,
              let startY = proxy.position(forY: point.value),
              let candidate: Double = proxy.value(atY: startY + value.translation.height) else { return }
        draggedValue = min(point.maximum, max(0, candidate))
    }

    private enum Constants {
        static let editTapCount = 2
        static let pointHitRadius: CGFloat = 22
        static let yIntervals = 4.0
        static let pointSize: CGFloat = 8
        static let selectedSize: CGFloat = 18
        static let pointBorder: CGFloat = 2
        static let lineWidth: CGFloat = 2.5
        static let referenceWidth: CGFloat = 1
        static let gridWidth: CGFloat = 0.5
        static let legendWidth: CGFloat = 18
        static let dragThreshold: CGFloat = 4
        static let fillOpacity = 0.2
        static let fadeOpacity = 0.015
        static let referenceOpacity = 0.65
        static let guideOpacity = 0.4
        static let dash: [CGFloat] = [4, 4]
        static let rpmTicks = [1_000.0, 3_000.0, 5_000.0, 7_000.0, 9_000.0, 11_000.0, 13_000.0, 15_000.0]
        static let rpmRange = 1_000.0 ... 15_000.0
        static let rpmDivisor = 1_000.0
        static let rpmKey = String(localized: .powerCurveRpm)
        static let seriesKey = "series"
        static let limitSeries = "limit"
        static let curveSeries = "curve"
    }
}
