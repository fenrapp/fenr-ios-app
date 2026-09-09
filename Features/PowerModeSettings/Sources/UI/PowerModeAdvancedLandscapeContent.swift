import DesignSystem
import SwiftUI

struct PowerModeAdvancedLandscapeContent: View {
    let state: PowerModeAdvancedViewState
    let maps: [PowerModeMapViewData]
    let send: (PowerModeAdvancedIntent) -> Void
    let size: CGSize

    var body: some View {
        HStack(alignment: .top, spacing: DesignSpace.medium) {
            VStack(spacing: .zero) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSpace.small) {
                        editor
                        feedback
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                PowerCurveActionButtons(state: state, send: send)
                    .padding(.horizontal, DesignSpace.small)
            }
            sidebar
        }
        .padding(.horizontal, DesignSpace.medium)
        .padding(.top, DesignSpace.extraSmall)
        .padding(.bottom, DesignSpace.small)
        .background(.background.secondary)
    }

    private var sidebar: some View {
        List {
            Section(.powerModeSettingsMapSection) {
                PowerModeSelector(maps: maps, select: { send(.selectMap($0)) })
                    .disabled(state.isBusy)
            }
            Section {
                HStack {
                    Text(state.kind == .power ? .powerCurvePeakLabel : .powerCurveMaximumLabel)
                    Spacer(minLength: DesignSpace.extraSmall)
                    Text(verbatim: state.summary)
                        .monospacedDigit()
                        .foregroundStyle(state.kind == .power ? DesignColor.warning : DesignColor.informational)
                }
                .font(.subheadline)
                VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                    Label(.powerCurveSetting, systemImage: "minus")
                        .foregroundStyle(state.kind == .power ? DesignColor.warning : DesignColor.informational)
                    Label(.powerCurveLimit, systemImage: "minus")
                        .foregroundStyle(DesignColor.secondaryText)
                }
                .font(.caption)
            }
            Section(.powerModeSettingsTractionGroupTitle) {
                ForEach(state.tractionAdjustments) { adjustment in
                    PowerModeAdjustmentRow(state: adjustment) { value in
                        send(.setTraction(id: adjustment.id, value: value))
                    }
                }
            }
            PowerCurvePresetsSection(state: state, send: send)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(DesignSpace.medium)
        .contentMargins(.vertical, .zero, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .frame(width: max(Constants.minimumSidebarWidth, size.width * Constants.sidebarRatio))
    }

    private var editor: some View {
        VStack(spacing: DesignSpace.extraSmall) {
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
                chartHeight: max(Constants.minimumChartHeight, size.height - Constants.editorChromeHeight),
                showsHeader: false
            )
            .id("\(state.kind)-\(maps.first(where: \.isSelected)?.id ?? 0)")
        }
        .padding(DesignSpace.small)
        .background(.background, in: RoundedRectangle(cornerRadius: DesignRadius.medium))
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            if state.isBusy {
                ProgressView { Text(.powerCurveWorking) }
            }
            if let message = state.message {
                Text(verbatim: message)
            }
            Text(state.kind == .power ? .powerCurvePowerGuide : .powerCurveRegenGuide)
            Text(state.hasDraft ? .powerCurvePending : .powerCurveStored)
        }
        .font(.footnote)
        .foregroundStyle(DesignColor.secondaryText)
        .padding(.horizontal, DesignSpace.small)
        .padding(.bottom, DesignSpace.small)
    }

    private enum Constants {
        static let minimumSidebarWidth: CGFloat = 260
        static let sidebarRatio: CGFloat = 0.34
        static let minimumChartHeight: CGFloat = 140
        static let editorChromeHeight: CGFloat = 140
    }
}
