import DesignSystem
import SwiftUI

struct PowerModeAdvancedContent: View {
    let state: PowerModeAdvancedViewState
    let maps: [PowerModeMapViewData]
    let send: (PowerModeAdvancedIntent) -> Void

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height, state.hasConfiguration {
                PowerModeAdvancedLandscapeContent(state: state, maps: maps, send: send, size: geometry.size)
            } else {
                portraitContent(chartHeight: geometry.size.width < Constants.compactWidth
                    ? Constants.compactChartHeight : Constants.chartHeight)
            }
        }
        .navigationTitle(Text(.powerCurveAdvancedTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { send(.refresh) }, label: { Image(systemName: "arrow.clockwise") })
                    .disabled(state.isBusy)
                    .accessibilityLabel(.powerModeSettingsRefreshAccessibility)
            }
        }
    }

    private func portraitContent(chartHeight: CGFloat) -> some View {
        List {
            Section(.powerModeSettingsMapSection) {
                PowerModeSelector(maps: maps, select: { send(.selectMap($0)) })
                    .disabled(state.isBusy)
            }
            if state.hasConfiguration {
                curveSection(chartHeight: chartHeight)
                Section(.powerModeSettingsTractionGroupTitle) {
                    ForEach(state.tractionAdjustments) { adjustment in
                        PowerModeAdjustmentRow(state: adjustment) { value in
                            send(.setTraction(id: adjustment.id, value: value))
                        }
                    }
                }
                PowerCurvePresetsSection(state: state, send: send)
            } else {
                Section {
                    Text(.powerCurveLoadingDescription)
                        .foregroundStyle(DesignColor.secondaryText)
                    Button(.powerCurveRead, action: { send(.refresh) })
                        .disabled(state.isBusy)
                    operationFeedback
                }
            }
        }
        .listSectionSpacing(DesignSpace.medium)
    }

    private func curveSection(chartHeight: CGFloat) -> some View {
        Section {
            Picker(.powerCurveCurve, selection: Binding(
                get: { state.kind }, set: { send(.selectCurve($0)) }
            )) {
                Text(.powerCurvePower).tag(PowerModeCurveKind.power)
                Text(.powerCurveRegeneration).tag(PowerModeCurveKind.regeneration)
            }
            .pickerStyle(.segmented)
            PowerCurveEditor(
                points: state.points, samples: state.samples, kind: state.kind,
                unit: state.unit, summary: state.summary,
                isEnabled: state.canEdit, commit: { send(.setPoint(index: $0, value: $1)) },
                chartHeight: chartHeight
            )
            .id("\(state.kind)-\(maps.first(where: \.isSelected)?.id ?? 0)")
            .listRowInsets(EdgeInsets(
                top: .zero, leading: DesignSpace.medium, bottom: .zero, trailing: DesignSpace.medium
            ))
            PowerCurveActionButtons(state: state, send: send)
            operationFeedback
        } footer: {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(state.kind == .power ? .powerCurvePowerGuide : .powerCurveRegenGuide)
                Text(state.hasDraft ? .powerCurvePending : .powerCurveStored)
            }
        }
    }

    @ViewBuilder
    private var operationFeedback: some View {
        if state.isBusy {
            ProgressView {
                Text(.powerCurveWorking)
            }
            .font(.footnote)
        }
        if let message = state.message {
            Text(verbatim: message)
                .font(.footnote)
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private enum Constants {
        static let compactWidth: CGFloat = 390
        static let compactChartHeight: CGFloat = 210
        static let chartHeight: CGFloat = 260
    }
}
