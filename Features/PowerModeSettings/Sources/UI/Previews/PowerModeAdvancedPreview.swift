#if DEBUG
import SwiftUI

private struct PowerModeAdvancedPreview: View {
    @State private var selectedMap = 0
    @State private var kind: PowerModeCurveKind = .power
    @State private var drafts: [Int: MapFixture] = [:]
    @State private var confirmed: [Int: MapFixture] = [:]

    private var baseline: MapFixture { confirmed[selectedMap] ?? MapFixture() }
    private var current: MapFixture { drafts[selectedMap] ?? baseline }
    private var hasDraft: Bool { current != baseline }
    private var power: [Double] { current.power }
    private var regeneration: [Double] { current.regeneration }

    var body: some View {
        NavigationStack {
            PowerModeAdvancedContent(
                state: state,
                maps: (0 ... 4).map { index in
                    .init(
                        id: index, title: index == 0 ? "Enduro" : "\(index + 1)",
                        accessibilityLabel: "Map \(index + 1)", isSelected: selectedMap == index
                    )
                },
                send: handle
            )
        }
    }

    private var state: PowerModeAdvancedViewState {
        let rpm = [1_000, 2_000, 3_000, 4_000, 5_000, 6_000, 8_000, 10_000, 12_000, 14_000]
        let maximum = [11.0, 22, 34, 41, 52, 67, 80, 80, 80, 80]
        return .init(
            tractionAdjustments: [
                traction(id: .powerTraction, title: "Traction control", value: current.powerTraction),
                traction(id: .brakingTraction, title: "Regen traction", value: current.regenTraction)
            ],
            points: rpm.enumerated().map { index, value in
                .init(
                    id: index, rpm: Double(value), rpmText: value.formatted(),
                    value: kind == .power ? power[index] : regeneration[index],
                    maximum: kind == .power ? maximum[index] : 100
                )
            },
            samples: samplePoints, kind: kind, unit: kind == .power ? "HP" : "%",
            summary: kind == .power
                ? "\(Int(power.max() ?? 0)) HP"
                : "\((regeneration.max() ?? 0).formatted(.number.precision(.fractionLength(0)))) %",
            canEdit: true, canApply: hasDraft, hasDraft: hasDraft,
            hasConfiguration: true,
            presets: [
                .init(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    name: "Enduro", isCompatible: true
                ),
                .init(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    name: "Wet terrain", isCompatible: true
                )
            ],
            canSavePreset: true
        )
    }

    private var samplePoints: [PowerCurvePointViewData] {
        let indexes = [0, 1, 2, 3, 4, 5, 7, 9, 11, 13]
        let limits = [11.0, 22, 34, 41, 52, 67, 79, 80, 80, 80, 80, 80, 80, 80, 80]
        let values = kind == .power ? power : regeneration
        return (0 ..< 15).map { index in
            let value: Double
            if let editorIndex = indexes.firstIndex(of: index) {
                value = values[editorIndex]
            } else if index == 14 {
                value = values[9]
            } else {
                let next = indexes.firstIndex { $0 > index }!
                value = (values[next - 1] + values[next]) / 2
            }
            return .init(
                id: index, rpm: Double((index + 1) * 1_000), rpmText: "\((index + 1) * 1_000)",
                value: value, maximum: kind == .power ? limits[index] : 100
            )
        }
    }

    private func traction(id: PowerModeAdjustmentID, title: String, value: Double) -> PowerModeAdjustmentViewState {
        .init(
            id: id, title: title, value: value, valueText: value.formatted(), unit: "%",
            minimum: 0, maximum: 100, step: 1, isEnabled: true,
            localeIdentifier: "en_US", feedback: .idle
        )
    }

    private func handle(_ intent: PowerModeAdvancedIntent) {
        switch intent {
        case .selectMap(let index): selectedMap = index
        case .selectCurve(let selected): kind = selected
        case .setPoint(let index, let value):
            var draft = current
            if kind == .power { draft.power[index] = value } else { draft.regeneration[index] = value }
            drafts[selectedMap] = draft
        case .setTraction(let id, let value):
            var draft = current
            if id == .powerTraction { draft.powerTraction = value } else { draft.regenTraction = value }
            drafts[selectedMap] = draft
        case .apply:
            confirmed[selectedMap] = current
            drafts[selectedMap] = nil
        case .discard:
            drafts[selectedMap] = nil
        default: break
        }
    }
    private struct MapFixture: Equatable {
        var power = [8.0, 17, 26, 34, 45, 53, 65, 70, 73, 75]
        var regeneration = [20.0, 24, 30, 35, 40, 45, 45, 42, 38, 35]
        var powerTraction = 65.0
        var regenTraction = 45.0
    }

}

#Preview("Advanced power modes") {
    PowerModeAdvancedPreview()
}
#endif
