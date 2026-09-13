import DesignSystem
import SwiftUI

struct PowerModeAdvancedLandscapeContent: View {
    @State private var showsOptions = false
    let state: PowerModeAdvancedViewState
    let maps: [PowerModeMapViewData]
    let send: (PowerModeAdvancedIntent) -> Void
    let editPoint: (PowerCurvePointViewData) -> Void
    let availableWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            if showsOptions {
                PowerModeAdvancedOptionsContent(state: state, maps: maps, send: send)
            } else if state.hasConfiguration {
                GeometryReader { geometry in
                    PowerCurveEditor(
                        points: state.points, samples: state.samples, kind: state.kind,
                        unit: state.unit, summary: state.summary,
                        isEnabled: state.canEdit, commit: { send(.setPoint(index: $0, value: $1)) },
                        editPoint: editPoint,
                        chartHeight: geometry.size.height,
                        showsHeader: false, isExpanded: true
                    )
                    .id("\(state.kind)-\(maps.first(where: \.isSelected)?.id ?? 0)")
                }
                .clipped()
            } else {
                VStack(spacing: DesignSpace.medium) {
                    Text(.powerCurveLoadingDescription)
                        .foregroundStyle(DesignColor.secondaryText)
                    Button(.powerCurveRead) { send(.refresh) }
                        .disabled(state.isBusy)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            footer
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignSpace.medium)
        .padding(.top, DesignSpace.extraSmall)
        .padding(.bottom, DesignSpace.medium)
        .ignoresSafeArea(.container, edges: .bottom)
        .background(.background)
        .toolbar {
            ToolbarItem(placement: .principal) {
                tabs
                    .frame(width: availableWidth * Constants.toolbarWidthRatio)
            }
        }
    }

    private var tabs: some View {
        Picker(.powerCurveCurve, selection: Binding<PowerModeCurveKind?>(
            get: { showsOptions ? nil : state.kind },
            set: { kind in
                showsOptions = kind == nil
                if let kind { send(.selectCurve(kind)) }
            }
        )) {
            Text(.powerCurvePower).tag(Optional(PowerModeCurveKind.power))
            Text(.powerCurveRegeneration).tag(Optional(PowerModeCurveKind.regeneration))
            Text(.powerCurveOptions).tag(Optional<PowerModeCurveKind>.none)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("powerModes.advanced.tabs")
    }

    private var footer: some View {
        HStack(spacing: DesignSpace.medium) {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                if let map = maps.first(where: \.isSelected) {
                    Text(verbatim: map.accessibilityLabel)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(verbatim: state.summary)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(state.kind == .power ? DesignColor.warning : DesignColor.informational)
            }
            if state.isBusy {
                ProgressView().accessibilityLabel(.powerCurveWorking)
            } else if let message = state.message {
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(DesignColor.secondaryText)
                    .lineLimit(Constants.feedbackLineLimit)
            }
            PowerCurveActionButtons(state: state, send: send, controlSize: .large, verticalPadding: .zero)
        }
    }

    private enum Constants {
        static let toolbarWidthRatio: CGFloat = 0.7
        static let feedbackLineLimit = 2
    }
}
