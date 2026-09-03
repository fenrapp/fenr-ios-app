import SwiftUI

struct DiagnosticsStatusView: View {
    let state: BikeDiagnosticsViewState

    var body: some View {
        List {
            Section(DiagnosticsCopy.decodedStatus) {
                ForEach(state.decodedStatus) { DiagnosticsMetricRow(metric: $0) }
            }
            Section {
                ForEach(state.rawFlags) { DiagnosticsMetricRow(metric: $0) }
            } header: {
                Text(verbatim: DiagnosticsCopy.originalBitfields)
            } footer: {
                Text(verbatim: DiagnosticsCopy.statusFooter)
            }
        }
    }
}
